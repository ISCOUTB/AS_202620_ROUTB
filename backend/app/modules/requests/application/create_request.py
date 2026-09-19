from sqlalchemy.orm import Session

from app.modules.requests.domain.exceptions import (
    ActiveRequestAlreadyExistsError,
    DriverCannotRequestError,
    NoAvailableSeatsError,
    TripNotActiveError,
)
from app.modules.requests.infrastructure.models import TripRequest
from app.modules.trips.infrastructure.models import Trip


def create_request(db: Session, trip_id: int, passenger_id: int) -> TripRequest:
    trip = db.get(Trip, trip_id)
    if not trip or trip.status != "active":
        raise TripNotActiveError("El viaje no existe o no está activo")

    if trip.driver_id == passenger_id:
        raise DriverCannotRequestError("El conductor no puede solicitar cupo en su propio viaje")

    if trip.available_seats <= 0:
        raise NoAvailableSeatsError("No hay cupos disponibles en este viaje")

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
        status="pending",
    )
    db.add(request)
    db.commit()
    db.refresh(request)
    return request
