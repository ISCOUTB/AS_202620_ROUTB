from sqlalchemy import delete, update
from sqlalchemy.orm import Session, joinedload

from app.modules.requests.domain.exceptions import (
    InvalidRequestStateError,
    NoSeatsToAcceptError,
    TripRequestNotFoundError,
    UnauthorizedRequestActionError,
)
from app.modules.requests.infrastructure.models import TripRequest
from app.modules.trips.application import (
    release_request_seats,
    reserve_request_seats,
)


def accept_request(db: Session, request_id: int, driver_id: int | None = None) -> TripRequest:
    request = (
        db.query(TripRequest)
        .options(joinedload(TripRequest.trip))
        .filter(TripRequest.id == request_id)
        .first()
    )
    if not request:
        raise TripRequestNotFoundError()

    trip = request.trip
    if driver_id is not None and trip.driver_id is not None and trip.driver_id != driver_id:
        raise UnauthorizedRequestActionError("No tienes permiso para gestionar esta solicitud")

    if request.status == "accepted":
        return request
    if request.status != "pending":
        raise InvalidRequestStateError("Solo se pueden aceptar solicitudes pendientes")

    transitioned = db.execute(
        update(TripRequest)
        .where(TripRequest.id == request_id, TripRequest.status == "pending")
        .values(status="accepted")
        .execution_options(synchronize_session=False)
    )
    if transitioned.rowcount != 1:
        db.rollback()
        db.refresh(request)
        if request.status == "accepted":
            return request
        raise InvalidRequestStateError()

    if not reserve_request_seats(db, request.trip_id, request.seat_count):
        db.rollback()
        raise NoSeatsToAcceptError(
            "No hay suficientes cupos disponibles para aceptar el grupo completo"
        )

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
        raise TripRequestNotFoundError()

    trip = request.trip
    if driver_id is not None and trip.driver_id is not None and trip.driver_id != driver_id:
        raise UnauthorizedRequestActionError("No tienes permiso para gestionar esta solicitud")

    if request.status == "rejected":
        return request

    old_status = request.status
    transitioned = db.execute(
        update(TripRequest)
        .where(TripRequest.id == request_id, TripRequest.status == old_status)
        .values(status="rejected")
        .execution_options(synchronize_session=False)
    )
    if transitioned.rowcount != 1:
        db.rollback()
        db.refresh(request)
        if request.status == "rejected":
            return request
        raise InvalidRequestStateError()

    if old_status == "accepted" and not release_request_seats(
        db, request.trip_id, request.seat_count
    ):
        db.rollback()
        raise InvalidRequestStateError("No fue posible liberar todos los cupos del grupo")

    db.commit()
    db.refresh(request)
    return request


def withdraw_request(db: Session, request_id: int, passenger_id: int) -> None:
    """Retira la solicitud del pasajero y libera el grupo una sola vez."""
    request = db.query(TripRequest).filter(TripRequest.id == request_id).first()
    if not request:
        raise TripRequestNotFoundError()
    if request.passenger_id != passenger_id:
        raise UnauthorizedRequestActionError("Solo puedes retirar tu propia solicitud")

    removed = db.execute(
        delete(TripRequest)
        .where(
            TripRequest.id == request_id,
            TripRequest.passenger_id == passenger_id,
        )
        .returning(TripRequest.trip_id, TripRequest.seat_count, TripRequest.status)
    ).one_or_none()
    if removed is None:
        db.rollback()
        raise TripRequestNotFoundError()

    if removed.status == "accepted" and not release_request_seats(
        db, removed.trip_id, removed.seat_count
    ):
        db.rollback()
        raise InvalidRequestStateError("No fue posible liberar todos los cupos del grupo")

    db.commit()
