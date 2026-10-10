from datetime import datetime

from geoalchemy2.elements import WKTElement
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.timezone import colombia_now
from app.modules.notifications.application.manage_device_token import get_tokens_for_user
from app.modules.notifications.application.send_notification import send_push
from app.modules.requests.domain.exceptions import (
    ActiveRequestAlreadyExistsError,
    DriverCannotRequestError,
    NoAvailableSeatsError,
    TripNotActiveError,
)
from app.modules.requests.infrastructure.models import RequestStop, TripRequest
from app.modules.trips.application import get_trip_request_context
from app.modules.users.infrastructure.models import User


def create_request(
    db: Session,
    trip_id: int,
    passenger_id: int,
    seat_count: int = 1,
    requested_at: datetime | None = None,
    stops: list[dict] | None = None,
) -> TripRequest:
    if seat_count < 1 or seat_count > 4:
        raise NoAvailableSeatsError("La solicitud debe ser de 1 a 4 cupos")

    trip = get_trip_request_context(db, trip_id)
    if not trip or trip.status != "active":
        raise TripNotActiveError("El viaje no existe o no está activo")

    if trip.driver_id == passenger_id:
        raise DriverCannotRequestError("El conductor no puede solicitar cupo en su propio viaje")

    if trip.available_seats < seat_count:
        raise NoAvailableSeatsError(
            "No hay suficientes cupos disponibles para esta solicitud"
        )

    stop_data = stops or []
    if trip.direction in ("to_campus", "from_campus"):
        consent = db.execute(
            select(User.location_consent_at).where(User.id == passenger_id)
        ).scalar_one_or_none()
        if consent is None:
            raise PermissionError("location_consent_required")
        if not stop_data:
            raise ValueError("Se requiere al menos una parada para este viaje")
        if sum(int(stop["seats"]) for stop in stop_data) != seat_count:
            raise ValueError("La suma de cupos de las paradas debe coincidir con seat_count")
        if trip.direction == "to_campus" and len(stop_data) != 1:
            raise ValueError("En viajes hacia UTB se requiere una sola parada")
        if trip.direction == "from_campus" and len(stop_data) > seat_count:
            raise ValueError("No puede haber más paradas que pasajeros")

        try:
            lon_min, lat_min, lon_max, lat_max = map(
                float, settings.GEOCODE_BBOX.split(",")
            )
        except (ValueError, AttributeError):
            lon_min, lat_min, lon_max, lat_max = -180, -90, 180, 90
        for stop in stop_data:
            lat, lng = float(stop["lat"]), float(stop["lng"])
            if not (lon_min <= lng <= lon_max and lat_min <= lat <= lat_max):
                raise ValueError("Las coordenadas de la parada están fuera del área de operación")

    existing = (
        db.query(TripRequest)
        .filter(
            TripRequest.trip_id == trip_id,
            TripRequest.passenger_id == passenger_id,
            TripRequest.status.in_(["pending", "accepted"]),
        )
        .first()
    )
    if existing:
        raise ActiveRequestAlreadyExistsError("Ya tienes una solicitud activa para este viaje")

    request = TripRequest(
        trip_id=trip_id,
        passenger_id=passenger_id,
        seat_count=seat_count,
        status="pending",
        requested_at=requested_at or colombia_now(),
    )
    db.add(request)
    db.flush()
    for stop in stop_data:
        db.add(
            RequestStop(
                request_id=request.id,
                seats=stop["seats"],
                place_type=stop["place_type"],
                stop_geom=WKTElement(f"POINT({stop['lng']} {stop['lat']})", srid=4326),
                address_text=stop["address_text"],
            )
        )
    db.commit()
    db.refresh(request)
    if trip.driver_id is not None:
        try:
            tokens = get_tokens_for_user(db, trip.driver_id)
            if tokens:
                send_push(
                    [token.device_token for token in tokens],
                    title="Nueva solicitud de viaje",
                    body="Un pasajero solicitó cupo en tu viaje.",
                    data={"trip_id": str(trip_id), "event": "request_created"},
                    db=db,
                )
        except Exception:
            pass
    return request
