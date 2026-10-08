"""Caso de uso: crear un viaje (Fase 1 — con geocodificación y routing).

Flujo de escritura:
1. Validar consentimiento de ubicación si el conductor aporta coordenadas.
2. Calcular ``origin_geom`` y ``dest_geom`` a partir de ``driver_point``
   y la ubicación del campus (según el sentido del viaje).
3. ``commit`` del viaje (transacción corta, sin llamadas HTTP dentro).
4. Fuera de la transacción: llamar a ``RoutingService`` y persistir
   ``route_geom``, ``route_distance_m``, ``route_duration_s`` y
   ``route_source`` en el viaje recién creado.

Los viajes sin ``direction`` ni coordenadas siguen funcionando como antes.
"""

from __future__ import annotations

import json
import logging
from datetime import datetime
import re
from zoneinfo import ZoneInfo

from geoalchemy2.functions import ST_GeomFromGeoJSON
from sqlalchemy.orm import Session

from app.core.config import settings
from app.modules.trips.infrastructure.models import Trip
from app.modules.trips.infrastructure.schemas import TripCreate

logger = logging.getLogger(__name__)


def _parse_departure_to_timestamptz(date_val, time_str: str | None) -> datetime | None:
    if not date_val or not time_str:
        return None
    time_str = time_str.strip()
    match = re.match(r"^(\d{1,2}):(\d{2})\s*(AM|PM)?$", time_str, re.IGNORECASE)
    if not match:
        return None
    hour = int(match.group(1))
    minute = int(match.group(2))
    period = match.group(3)
    if period:
        period = period.upper()
        if period == "PM" and hour < 12:
            hour += 12
        elif period == "AM" and hour == 12:
            hour = 0
    if not (0 <= hour <= 23 and 0 <= minute <= 59):
        return None
    try:
        dt = datetime(date_val.year, date_val.month, date_val.day, hour, minute)
        return dt.replace(tzinfo=ZoneInfo("America/Bogota"))
    except Exception:
        return None


def _point_geojson(lat: float, lng: float) -> str:
    """Devuelve el GeoJSON de un punto para usarlo con ST_GeomFromGeoJSON."""
    return json.dumps({"type": "Point", "coordinates": [lng, lat]})


def _validate_consent(db: Session, driver_id: int | None) -> None:
    """Lanza ValueError si el conductor no ha dado consentimiento."""
    if driver_id is None:
        return
    from sqlalchemy import text

    row = db.execute(
        text(
            "SELECT location_consent_at FROM users WHERE id = :uid"
        ).bindparams(uid=driver_id)
    ).fetchone()
    if row is None or row[0] is None:
        raise PermissionError("location_consent_required")


def _validate_bbox(lat: float, lng: float) -> None:
    """Lanza ValueError si la coordenada está fuera del GEOCODE_BBOX."""
    try:
        parts = [float(x) for x in settings.GEOCODE_BBOX.split(",")]
        lon_min, lat_min, lon_max, lat_max = parts
    except (ValueError, AttributeError):
        return
    if not (lon_min <= lng <= lon_max and lat_min <= lat <= lat_max):
        raise ValueError("Las coordenadas del viaje están fuera del área de operación.")


def create_trip(db: Session, trip_data: TripCreate, driver_id: int | None = None) -> Trip:
    """Crea un viaje y, si se aportan coordenadas, calcula la ruta.

    Args:
        db: sesión de base de datos.
        trip_data: datos del viaje (incluye los nuevos campos opcionales
            ``direction`` y ``driver_point``).
        driver_id: ID del conductor autenticado (puede ser ``None`` en tests
            anónimos).

    Returns:
        El objeto ``Trip`` persistido y refrescado.

    Raises:
        PermissionError: si el conductor no tiene consentimiento de ubicación
            y aporta coordenadas.
        ValueError: si las coordenadas están fuera del bounding box.
    """
    dep_time = trip_data.departure_time or "7:00 AM"
    dep_at = _parse_departure_to_timestamptz(trip_data.departure_date, dep_time)

    driver_point = getattr(trip_data, "driver_point", None)
    direction = getattr(trip_data, "direction", None)

    lat = getattr(driver_point, "lat", None) if driver_point is not None and not isinstance(driver_point, dict) else (driver_point.get("lat") if isinstance(driver_point, dict) else None)
    lng = getattr(driver_point, "lng", None) if driver_point is not None and not isinstance(driver_point, dict) else (driver_point.get("lng") if isinstance(driver_point, dict) else None)

    # Si el conductor aporta coordenadas, validar consentimiento y bbox
    if driver_point and driver_id:
        _validate_consent(db, driver_id)
        if lat is not None and lng is not None:
            _validate_bbox(lat, lng)

    # Calcular geometrías
    origin_geom = None
    dest_geom = None

    if driver_point and direction and lat is not None and lng is not None:
        campus_geojson = _point_geojson(settings.UTB_CAMPUS_LAT, settings.UTB_CAMPUS_LNG)
        driver_geojson = _point_geojson(lat, lng)

        if direction == "to_campus":
            # El conductor sale desde su punto hacia el campus
            origin_geom = ST_GeomFromGeoJSON(driver_geojson)
            dest_geom = ST_GeomFromGeoJSON(campus_geojson)
        elif direction == "from_campus":
            # El conductor sale del campus hacia su destino
            origin_geom = ST_GeomFromGeoJSON(campus_geojson)
            dest_geom = ST_GeomFromGeoJSON(driver_geojson)

    trip = Trip(
        origin=trip_data.origin,
        destination=trip_data.destination,
        total_seats=trip_data.total_seats,
        available_seats=trip_data.total_seats,
        departure_time=dep_time,
        departure_date=trip_data.departure_date,
        departure_at=dep_at,
        meeting_point=trip_data.meeting_point.strip(),
        driver_id=driver_id,
        status="active",
        direction=direction,
        origin_geom=origin_geom,
        dest_geom=dest_geom,
    )
    db.add(trip)
    db.commit()
    db.refresh(trip)

    # Calcular ruta fuera de la transacción (llamadas HTTP)
    if driver_point and direction and lat is not None and lng is not None:
        _calculate_and_persist_route(db, trip, lat, lng, direction)

    return trip


def _calculate_and_persist_route(
    db: Session,
    trip: Trip,
    driver_lat: float,
    driver_lng: float,
    direction: str,
) -> None:
    """Llama a RoutingService y actualiza el viaje con la geometría de la ruta.

    Si OSRM falla se guarda el respaldo geodésico. Los errores se registran
    pero no propagan (el viaje ya está creado y el usuario no debe ver un error
    por el cálculo de la ruta).
    """
    try:
        from app.shared.routing.service import calculate_route

        campus = (settings.UTB_CAMPUS_LAT, settings.UTB_CAMPUS_LNG)
        driver = (driver_lat, driver_lng)
        coords = [driver, campus] if direction == "to_campus" else [campus, driver]

        route = calculate_route(db, coords)

        # Construir LineString GeoJSON a partir de la geometría devuelta por OSRM
        line_geojson = json.dumps(
            {"type": "LineString", "coordinates": route["geometry"]}
        )

        from sqlalchemy import text

        db.execute(
            text(
                """
                UPDATE trips SET
                    route_geom      = ST_GeomFromGeoJSON(:geom),
                    route_distance_m = :dist,
                    route_duration_s = :dur,
                    route_source    = :src
                WHERE id = :id
                """
            ).bindparams(
                geom=line_geojson,
                dist=route["distance_m"],
                dur=route["duration_s"],
                src=route["source"],
                id=trip.id,
            )
        )
        db.commit()
        db.refresh(trip)
    except Exception as exc:
        logger.warning("No se pudo calcular la ruta para el viaje %s: %s", trip.id, exc)
