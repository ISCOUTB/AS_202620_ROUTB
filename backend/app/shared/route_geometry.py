"""Lectura de la geometría de ruta que PostGIS guarda en ``trips.route_geom``.

La API expone la ruta como una lista de puntos ``(lat, lng)`` para que el
cliente Flutter dibuje exactamente la línea calculada por el backend, sin
volver a pedirla a Google Maps. La geometría se simplifica en SQL para no
enviar cientos de vértices irrelevantes en cada respuesta.
"""

from __future__ import annotations

import json
from typing import Iterable

from sqlalchemy import bindparam, text
from sqlalchemy.orm import Session

from app.shared.schemas import RoutePoint

# Tolerancia de simplificación (~5 m en la latitud de Cartagena). Conserva la
# forma de la vía y reduce el tamaño de la respuesta.
DEFAULT_SIMPLIFY_TOLERANCE = 0.00005


def parse_route_geojson(raw: object) -> list[RoutePoint]:
    """Convierte el GeoJSON de una ``LineString`` en puntos ``(lat, lng)``."""
    if raw is None:
        return []
    try:
        data = json.loads(raw) if isinstance(raw, str) else raw
    except (TypeError, ValueError):
        return []
    if not isinstance(data, dict):
        return []
    coordinates = data.get("coordinates")
    if not isinstance(coordinates, list):
        return []

    points: list[RoutePoint] = []
    for coordinate in coordinates:
        if not isinstance(coordinate, (list, tuple)) or len(coordinate) < 2:
            continue
        try:
            lng = float(coordinate[0])
            lat = float(coordinate[1])
        except (TypeError, ValueError):
            continue
        points.append(RoutePoint(lat=lat, lng=lng))
    return points


def routes_for_trips(
    db: Session,
    trip_ids: Iterable[int],
    *,
    tolerance: float = DEFAULT_SIMPLIFY_TOLERANCE,
) -> dict[int, list[RoutePoint]]:
    """Devuelve la ruta de cada viaje, indexada por id.

    Los viajes sin ``route_geom`` o con una geometría ilegible quedan fuera del
    diccionario: el llamador debe tratarlos como «sin ruta calculada».
    """
    ids = sorted({int(trip_id) for trip_id in trip_ids})
    if not ids:
        return {}

    statement = text(
        """
        SELECT id,
               ST_AsGeoJSON(ST_Simplify(route_geom, :tolerance)) AS geojson
        FROM trips
        WHERE id IN :trip_ids
          AND route_geom IS NOT NULL
        """
    ).bindparams(bindparam("trip_ids", expanding=True))

    rows = db.execute(
        statement,
        {"trip_ids": ids, "tolerance": tolerance},
    ).mappings().all()

    routes: dict[int, list[RoutePoint]] = {}
    for row in rows:
        points = parse_route_geojson(row["geojson"])
        if points:
            routes[int(row["id"])] = points
    return routes
