"""Caso de uso público para actualizar la ruta calculada de un viaje."""

from sqlalchemy import text
from sqlalchemy.orm import Session


def set_trip_route(
    db: Session,
    trip_id: int,
    line_geojson: str,
    distance_m: int,
    duration_s: int,
    source: str,
) -> None:
    """Actualiza la geometría y métricas de ruta de un viaje. Propiedad exclusiva del módulo trips."""
    db.execute(
        text(
            """UPDATE trips SET route_geom = ST_SetSRID(ST_GeomFromGeoJSON(:geometry), 4326),
                      route_distance_m = :distance, route_duration_s = :duration,
                      route_source = :source WHERE id = :trip_id"""
        ).bindparams(
            geometry=line_geojson,
            distance=distance_m,
            duration=duration_s,
            source=source,
            trip_id=trip_id,
        )
    )
