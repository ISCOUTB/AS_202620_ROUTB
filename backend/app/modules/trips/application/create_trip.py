"""Caso de uso: crear un viaje (Fase 1 — con geocodificación y routing)."""

from __future__ import annotations
 
import json
import logging
from datetime import date, timedelta
from app.core.timezone import colombia_today
 
from geoalchemy2.functions import ST_GeomFromGeoJSON
from sqlalchemy.orm import Session
 
from app.core.config import settings
from app.modules.trips.application.departure import parse_departure_to_timestamptz
from app.modules.trips.domain.exceptions import VehicleRequiredError
from app.modules.trips.infrastructure.models import Trip
from app.modules.trips.infrastructure.schemas import TripCreate
from app.modules.users.application import get_user_by_id
 
logger = logging.getLogger(__name__)
 
 
def _validate_departure_date(departure_date: date) -> None:
    """Solo se permite publicar para hoy o mañana (hora de Colombia)."""
    today = colombia_today()
    if departure_date not in (today, today + timedelta(days=1)):
        raise ValueError("La fecha del viaje debe ser hoy o mañana")


def _point_geojson(lat: float, lng: float) -> str:
    """Devuelve el GeoJSON de un punto para usarlo con ST_GeomFromGeoJSON."""
    return json.dumps({"type": "Point", "coordinates": [lng, lat]})
 
 
def _validate_driver_vehicle(db: Session, driver_id: int | None) -> None:
    """Lanza VehicleRequiredError si el conductor no registró su vehículo completo.

    La regla vive en el servidor: no basta con la comprobación previa de la app.
    Los viajes publicados antes de este cambio no se tocan; solo se bloquean
    las creaciones nuevas.
    """
    if driver_id is None:
        raise VehicleRequiredError()
    user = get_user_by_id(db, driver_id)
    if user is None:
        raise ValueError("Usuario no encontrado")
    vehicle_fields = (user.vehicle_model, user.vehicle_plate, user.vehicle_color)
    if not all((value or "").strip() for value in vehicle_fields):
        raise VehicleRequiredError()


def _extract_coords(driver_point) -> tuple[float | None, float | None]:
    """Obtiene (lat, lng) de un ``driver_point`` que puede ser dict u objeto."""
    if driver_point is None:
        return None, None
    if isinstance(driver_point, dict):
        return driver_point.get("lat"), driver_point.get("lng")
    return getattr(driver_point, "lat", None), getattr(driver_point, "lng", None)
 
 
def _validate_driver_location(
    lat: float | None,
    lng: float | None,
) -> None:
    """Valida el rango de coordenadas cuando el conductor aporta ubicación."""
    if lat is not None and lng is not None:
        if not (-90 <= lat <= 90 and -180 <= lng <= 180):
            raise ValueError("Coordenadas del viaje fuera de rango.")
 
 
def _build_trip_geoms(direction: str | None, lat: float, lng: float):
    """Devuelve ``(origin_geom, dest_geom)`` según el sentido del viaje."""
    campus_geom = ST_GeomFromGeoJSON(
        _point_geojson(settings.UTB_CAMPUS_LAT, settings.UTB_CAMPUS_LNG)
    )
    driver_geom = ST_GeomFromGeoJSON(_point_geojson(lat, lng))
 
    if direction == "to_campus":
        # El conductor sale desde su punto hacia el campus
        return driver_geom, campus_geom
    if direction == "from_campus":
        # El conductor sale del campus hacia su destino
        return campus_geom, driver_geom
    return None, None
 
 
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
        VehicleRequiredError: si el conductor no registró modelo, color y
            placa del vehículo.
        ValueError: si la fecha no es hoy o mañana, o si las coordenadas
            están fuera de rango.
    """
    _validate_departure_date(trip_data.departure_date)
    _validate_driver_vehicle(db, driver_id)

    dep_time = trip_data.departure_time or "7:00 AM"
    dep_at = parse_departure_to_timestamptz(trip_data.departure_date, dep_time)

    driver_point = getattr(trip_data, "driver_point", None)
    direction = getattr(trip_data, "direction", None)
    lat, lng = _extract_coords(driver_point)
 
    if driver_point:
        _validate_driver_location(lat, lng)
 
    has_route_inputs = bool(driver_point and direction and lat is not None and lng is not None)
 
    origin_geom, dest_geom = (
        _build_trip_geoms(direction, lat, lng) if has_route_inputs else (None, None)
    )
 
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
    if has_route_inputs:
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
