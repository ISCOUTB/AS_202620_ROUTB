"""Caso de uso: sugerir viajes compatibles (Matching Fase 2).

Implementa el pipeline en 3 pasos:
1. Filtrado espacial PostGIS + ventana horaria (solo lectura, hasta 10 candidatos).
2. Routing de los 3 mejores con paradas proyectadas (ST_LineLocatePoint) para desvío y ETA.
3. Descarte por desvío máximo y ranking ponderado por score normalizado.
"""

from __future__ import annotations

from datetime import date, datetime, timedelta
import logging
from typing import Any, Literal

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.timezone import get_colombia_tz
from app.modules.matching.schemas import SuggestionItem
from app.modules.trips.application.create_trip import _parse_departure_to_timestamptz
from app.shared.routing.service import calculate_route

logger = logging.getLogger(__name__)


def suggest_trips(
    db: Session,
    passenger_id: int,
    direction: Literal["to_campus", "from_campus"],
    points: list[tuple[float, float]],
    trip_date: date,
    trip_time: str,
    seat_count: int = 1,
    relaxed: bool = False,
) -> list[SuggestionItem]:
    """Busca viajes activos compatibles y los devuelve ordenados por score."""
    if not points:
        return []

    # Parámetros estrictos vs relajados
    radius_m = 1500 if relaxed else settings.MATCHING_RADIUS_M
    time_window_min = 30 if relaxed else settings.MATCHING_TIME_WINDOW_MIN
    max_detour_min = 15 if relaxed else settings.MATCHING_MAX_DETOUR_MIN

    w_detour = settings.MATCHING_W_DETOUR
    w_wait = settings.MATCHING_W_WAIT
    w_approach = settings.MATCHING_W_APPROACH
    max_routing = settings.MATCHING_ROUTING_CANDIDATES
    max_results = settings.MATCHING_MAX_RESULTS

    requested_dt = _parse_departure_to_timestamptz(trip_date, trip_time)
    if requested_dt is None:
        # Fallback a las 07:00 de ese día
        requested_dt = datetime(trip_date.year, trip_date.month, trip_date.day, 7, 0, tzinfo=get_colombia_tz())

    # Construir cláusulas espaciales para cada punto
    # Cada punto debe estar a <= radius_m de la ruta
    # Y calculamos la distancia máxima (más lejana) entre los puntos y la ruta
    dwithin_clauses = []
    dist_clauses = []
    bind_params: dict[str, Any] = {
        "p_id": passenger_id,
        "direction": direction,
        "t_date": trip_date,
        "req_seats": seat_count,
        "radius_m": radius_m,
        "time_window_min": time_window_min,
        "req_dt": requested_dt,
    }

    for idx, (pt_lat, pt_lng) in enumerate(points):
        lat_k = f"lat_{idx}"
        lng_k = f"lng_{idx}"
        bind_params[lat_k] = pt_lat
        bind_params[lng_k] = pt_lng

        geom_expr = f"ST_SetSRID(ST_MakePoint(:{lng_k}, :{lat_k}), 4326)"
        dwithin_clauses.append(
            f"ST_DWithin(t.route_geom::geography, {geom_expr}::geography, :radius_m)"
        )
        dist_clauses.append(
            f"ST_Distance(t.route_geom::geography, {geom_expr}::geography)"
        )

    all_dwithin_sql = " AND ".join(dwithin_clauses)
    max_dist_sql = f"GREATEST({', '.join(dist_clauses)})" if len(dist_clauses) > 1 else dist_clauses[0]

    # Paso 1: Filtro SQL en PostGIS
    query_sql = f"""
        SELECT
            t.id,
            t.driver_id,
            u.name AS driver_name,
            u.last_name AS driver_last_name,
            u.phone AS driver_phone,
            t.origin,
            t.destination,
            t.direction,
            t.departure_date,
            t.departure_time,
            t.departure_at,
            t.total_seats,
            t.available_seats,
            t.route_duration_s,
            t.route_distance_m,
            t.route_source,
            ST_Y(t.origin_geom) AS origin_lat,
            ST_X(t.origin_geom) AS origin_lng,
            ST_Y(t.dest_geom) AS dest_lat,
            ST_X(t.dest_geom) AS dest_lng,
            {max_dist_sql} AS walk_distance_m
        FROM trips t
        JOIN users u ON u.id = t.driver_id
        WHERE t.status = 'active'
          AND t.direction = :direction
          AND t.departure_date = :t_date
          AND t.available_seats >= :req_seats
          AND t.driver_id != :p_id
          AND t.route_geom IS NOT NULL
          AND t.origin_geom IS NOT NULL
          AND t.dest_geom IS NOT NULL
          AND NOT EXISTS (
              SELECT 1 FROM trip_requests r
              WHERE r.trip_id = t.id
                AND r.passenger_id = :p_id
                AND r.status IN ('pending', 'accepted')
          )
          AND (
              t.departure_at IS NULL
              OR ABS(EXTRACT(EPOCH FROM (t.departure_at - :req_dt)) / 60) <= :time_window_min
          )
          AND {all_dwithin_sql}
        ORDER BY walk_distance_m ASC
        LIMIT 10;
    """

    candidates = db.execute(text(query_sql).bindparams(**bind_params)).mappings().all()
    if not candidates:
        return []

    # Paso 2: Evaluar hasta max_routing (3) candidatos mediante RoutingService
    scored_items: list[SuggestionItem] = []

    for row in candidates[:max_routing]:
        trip_id = row["id"]
        driver_id = row["driver_id"]
        driver_full_name = f"{row['driver_name']} {row['driver_last_name']}".strip()
        driver_phone = row["driver_phone"]
        origin = row["origin"]
        destination = row["destination"]
        dep_date = row["departure_date"]
        dep_time = row["departure_time"]
        dep_at = row["departure_at"]
        tot_seats = row["total_seats"]
        avail_seats = row["available_seats"]
        base_duration_s = row["route_duration_s"] or 0
        walk_dist_m = float(row["walk_distance_m"] or 0.0)
        origin_lat = row["origin_lat"]
        origin_lng = row["origin_lng"]
        dest_lat = row["dest_lat"]
        dest_lng = row["dest_lng"]

        # Proyectar paradas para ordenarlas a lo largo de la ruta usando ST_LineLocatePoint
        # Obtenemos loc para cada punto del pasajero
        point_locs: list[tuple[float, tuple[float, float]]] = []
        for p_lat, p_lng in points:
            loc_val = db.execute(
                text(
                    "SELECT ST_LineLocatePoint(t.route_geom, ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)) "
                    "FROM trips t WHERE t.id = :tid"
                ).bindparams(lng=p_lng, lat=p_lat, tid=trip_id)
            ).scalar()
            point_locs.append((float(loc_val or 0.0), (p_lat, p_lng)))

        # Ordenar los puntos según su posición a lo largo de la ruta
        point_locs.sort(key=lambda x: x[0])
        sorted_points = [p[1] for p in point_locs]
        first_loc = point_locs[0][0] if point_locs else 0.0

        # Trayectoria completa con las paradas insertadas
        coords_with_stops = [(origin_lat, origin_lng)] + sorted_points + [(dest_lat, dest_lng)]

        # Consultar RoutingService
        is_degraded = False
        try:
            route_res = calculate_route(db, coords_with_stops)
            new_duration_s = route_res.get("duration_s", base_duration_s)
            is_degraded = bool(route_res.get("degraded", False))
        except Exception as exc:
            logger.warning("Fallo al calcular ruta con desvío para viaje %s: %s", trip_id, exc)
            # En caso de fallo total, estimar desvío por distancia a pie * 2 a 25 km/h
            detour_s = int((walk_dist_m * 2 / (25_000 / 3600)))
            new_duration_s = base_duration_s + detour_s
            is_degraded = True

        detour_seconds = max(0, new_duration_s - base_duration_s)
        detour_minutes = round(detour_seconds / 60.0, 1)

        # Paso 3: Descarte por tope de desvío
        if detour_minutes > max_detour_min:
            continue

        # Calcular ETA de recogida
        trip_start_at = dep_at or requested_dt
        if direction == "from_campus":
            # Recogida en campus a la hora de salida
            eta_pickup = trip_start_at
        else:
            # Recogida en origen/puerta
            pickup_offset_s = int(new_duration_s * first_loc) if new_duration_s else 0
            eta_pickup = trip_start_at + timedelta(seconds=pickup_offset_s)

        # Cálculo de Score normalizado
        detour_norm = min(detour_minutes / max_detour_min, 1.0)
        wait_diff_min = abs((eta_pickup - requested_dt).total_seconds() / 60.0)
        wait_norm = min(wait_diff_min / time_window_min, 1.0)
        approach_norm = min(walk_dist_m / radius_m, 1.0)

        score = round(
            (w_detour * detour_norm) + (w_wait * wait_norm) + (w_approach * approach_norm),
            4,
        )

        scored_items.append(
            SuggestionItem(
                trip_id=trip_id,
                driver_id=driver_id,
                driver_name=driver_full_name,
                driver_phone=driver_phone,
                origin=origin,
                destination=destination,
                direction=direction,
                departure_date=dep_date,
                departure_time=dep_time,
                departure_at=dep_at,
                eta_pickup=eta_pickup,
                detour_minutes=detour_minutes,
                walk_distance_m=round(walk_dist_m, 1),
                score=score,
                available_seats=avail_seats,
                total_seats=tot_seats,
                degraded=is_degraded,
            )
        )

    # Ordenar por score ascendente (menor score = mejor compatibilidad)
    scored_items.sort(key=lambda item: item.score)
    return scored_items[:max_results]
