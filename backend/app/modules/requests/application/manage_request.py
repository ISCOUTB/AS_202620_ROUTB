from sqlalchemy.orm import Session, joinedload

from app.modules.requests.domain.exceptions import (
    NoSeatsToAcceptError,
    TripRequestNotFoundError,
    UnauthorizedRequestActionError,
)
from app.modules.requests.infrastructure.models import TripRequest


def accept_request(db: Session, request_id: int, driver_id: int | None = None) -> TripRequest:
    request = (
        db.query(TripRequest)
        .options(joinedload(TripRequest.trip))
        .filter(TripRequest.id == request_id)
        .first()
    )
    if not request:
        raise TripRequestNotFoundError("Solicitud no encontrada")

    trip = request.trip
    if driver_id is not None and trip.driver_id is not None and trip.driver_id != driver_id:
        raise UnauthorizedRequestActionError("No tienes permiso para gestionar esta solicitud")

    if request.status == "accepted":
        return request

    if trip.available_seats <= 0:
        raise NoSeatsToAcceptError("No hay cupos disponibles para aceptar más pasajeros")

    trip.available_seats -= 1
    request.status = "accepted"
    db.commit()
    db.refresh(request)
    return request


def reject_request(db: Session, request_id: int, driver_id: int | None = None) -> TripRequest:
    request = (
        db.query(TripRequest)
        .options(joinedload(TripRequest.trip))
        .filter(TripRequest.id == request_id)
        .first()
    )
    if not request:
        raise TripRequestNotFoundError("Solicitud no encontrada")

    trip = request.trip
    if driver_id is not None and trip.driver_id is not None and trip.driver_id != driver_id:
        raise UnauthorizedRequestActionError("No tienes permiso para gestionar esta solicitud")

    if request.status == "accepted":
        trip.available_seats = min(trip.total_seats, trip.available_seats + 1)

    request.status = "rejected"
    db.commit()
    db.refresh(request)
    return request
