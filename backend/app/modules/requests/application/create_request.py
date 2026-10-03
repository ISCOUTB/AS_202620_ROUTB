from sqlalchemy.orm import Session

from app.modules.requests.domain.exceptions import (
    ActiveRequestAlreadyExistsError,
    DriverCannotRequestError,
    NoAvailableSeatsError,
    TripNotActiveError,
)
from app.modules.requests.infrastructure.models import TripRequest
from app.modules.trips.application import get_trip_request_context


def create_request(
    db: Session, trip_id: int, passenger_id: int, seat_count: int = 1
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
    )
    db.add(request)
    db.commit()
    db.refresh(request)
    return request
