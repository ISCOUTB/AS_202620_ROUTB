import logging

from sqlalchemy import delete, select, update
from sqlalchemy.orm import Session, joinedload
from sqlalchemy.exc import InvalidRequestError
from sqlalchemy.orm.exc import ObjectDeletedError
from app.modules.notifications.application.dispatch import PendingPush
from app.modules.requests.domain.exceptions import (
    InvalidRequestStateError,
    RequestExpiredError,
    NoSeatsToAcceptError,
    TripRequestNotFoundError,
    UnauthorizedRequestActionError,
)
from app.modules.requests.infrastructure.models import RequestStop, TripRequest
from app.modules.requests.application.order_stops import (
    refresh_trip_route_and_stop_eta,
    reorder_accepted_stops,
)
from app.modules.requests.application.expire_requests import expire_stale_requests
from app.modules.trips.infrastructure.models import Trip
from app.modules.users.infrastructure.models import User
from app.modules.trips.application import (
    release_request_seats,
    reserve_request_seats,
)

logger = logging.getLogger(__name__)


def _validate_acceptance(
    db: Session, request_id: int, driver_id: int | None
) -> TripRequest:
    if db.get(TripRequest, request_id) is None:
        raise TripRequestNotFoundError()

    expire_stale_requests(db, request_id=request_id)
    refreshed_request = db.get(TripRequest, request_id)
    if refreshed_request is None:
        raise TripRequestNotFoundError()
    if refreshed_request.status == "expired":
        raise RequestExpiredError()

    if driver_id is not None and refreshed_request.trip.driver_id != driver_id:
        raise UnauthorizedRequestActionError("No tienes permiso para gestionar esta solicitud")
    if refreshed_request.status == "accepted":
        return refreshed_request
    if refreshed_request.status != "pending":
        raise InvalidRequestStateError("Solo se pueden aceptar solicitudes pendientes")
    return refreshed_request


def _validate_passenger_schedule(
    db: Session, request: TripRequest, trip: Trip | None
) -> None:
    if trip is None or not trip.direction:
        return

    db.execute(select(User.id).where(User.id == request.passenger_id).with_for_update()).scalar_one()
    assigned = (
        db.query(TripRequest.id)
        .join(Trip, Trip.id == TripRequest.trip_id)
        .filter(
            TripRequest.passenger_id == request.passenger_id,
            TripRequest.status == "accepted",
            TripRequest.id != request.id,
            Trip.departure_date == trip.departure_date,
            Trip.direction == trip.direction,
        )
        .first()
    )
    if assigned:
        db.rollback()
        raise InvalidRequestStateError(
            "El pasajero ya tiene un viaje aceptado para ese día y sentido"
        )


def _transition_to_accepted(db: Session, request: TripRequest) -> TripRequest:
    request_id = request.id
    transitioned = db.execute(
        update(TripRequest)
        .where(TripRequest.id == request_id, TripRequest.status == "pending")
        .values(status="accepted")
        .execution_options(synchronize_session=False)
    )
    if transitioned.rowcount != 1:
        db.rollback()
        current = db.get(TripRequest, request_id)
        if current is None:
            raise TripRequestNotFoundError()
        if current.status == "accepted":
            return current
        raise InvalidRequestStateError()
    return request


def _cancel_alternative_requests(
    db: Session, request: TripRequest, trip: Trip | None
) -> None:
    if trip is None or not trip.direction:
        return

    cancelled_ids = db.execute(
        update(TripRequest)
        .where(
            TripRequest.passenger_id == request.passenger_id,
            TripRequest.status == "pending",
            TripRequest.id != request.id,
            TripRequest.trip_id.in_(
                select(Trip.id).where(
                    Trip.departure_date == trip.departure_date,
                    Trip.direction == trip.direction,
                )
            ),
        )
        .values(status="cancelled")
        .returning(TripRequest.id)
        .execution_options(synchronize_session=False)
    ).scalars().all()
    if cancelled_ids:
        db.execute(delete(RequestStop).where(RequestStop.request_id.in_(cancelled_ids)))

    reorder_accepted_stops(db, request.trip_id)


def _refresh_accepted_request(
    db: Session, request: TripRequest, trip: Trip | None
) -> None:
    if trip is None or not trip.direction:
        return

    try:
        refresh_trip_route_and_stop_eta(db, request.trip_id)
        db.refresh(request)
    except Exception:
        db.rollback()
        logger.exception("No se pudo recalcular la ruta del viaje %s", request.trip_id)


def _pending_request_push(
    request: TripRequest, *, event: str, title: str, body: str
) -> PendingPush:
    return PendingPush(
        user_id=request.passenger_id,
        title=title,
        body=body,
        data={"trip_id": str(request.trip_id), "event": event},
    )


def accept_request(
    db: Session, request_id: int, driver_id: int | None = None
) -> tuple[TripRequest, list[PendingPush]]:
    request = _validate_acceptance(db, request_id, driver_id)
    if request.status == "accepted":
        return request, []

    trip = db.query(Trip).filter(Trip.id == request.trip_id).first()
    _validate_passenger_schedule(db, request, trip)
    request = _transition_to_accepted(db, request)
    if not reserve_request_seats(db, request.trip_id, request.seat_count):
        db.rollback()
        raise NoSeatsToAcceptError(
            "No hay suficientes cupos disponibles para aceptar el grupo completo"
        )

    _cancel_alternative_requests(db, request, trip)
    db.commit()
    try:
        db.refresh(request)
    except ObjectDeletedError as exc:
        raise TripRequestNotFoundError() from exc
    except InvalidRequestError as exc:
        raise TripRequestNotFoundError() from exc

    _refresh_accepted_request(db, request, trip)
    return request, [
        _pending_request_push(
            request,
            event="request_accepted",
            title="Solicitud aceptada",
            body="El conductor ha aceptado tu solicitud de cupo.",
        )
    ]


def reject_request(
    db: Session, request_id: int, driver_id: int | None = None
) -> tuple[TripRequest, list[PendingPush]]:
    request = (
        db.query(TripRequest)
        .options(joinedload(TripRequest.trip))
        .filter(TripRequest.id == request_id)
        .first()
    )
    if not request:
        raise TripRequestNotFoundError()

    trip = request.trip
    if driver_id is not None and trip.driver_id != driver_id:
        raise UnauthorizedRequestActionError("No tienes permiso para gestionar esta solicitud")

    if request.status == "rejected":
        return request, []

    old_status = request.status
    transitioned = db.execute(
        update(TripRequest)
        .where(TripRequest.id == request_id, TripRequest.status == old_status)
        .values(status="rejected")
        .execution_options(synchronize_session=False)
    )
    if transitioned.rowcount != 1:
        db.rollback()
        current = db.get(TripRequest, request_id)
        if current is None:
            raise TripRequestNotFoundError()
        if current.status == "rejected":
            return current, []
        raise InvalidRequestStateError()

    if old_status == "accepted" and not release_request_seats(
        db, request.trip_id, request.seat_count
    ):
        db.rollback()
        raise InvalidRequestStateError("No fue posible liberar todos los cupos del grupo")

    db.commit()
    try:
        db.refresh(request)
    except ObjectDeletedError as exc:
        raise TripRequestNotFoundError() from exc
    except InvalidRequestError as exc:
        raise TripRequestNotFoundError() from exc

    return request, [
        _pending_request_push(
            request,
            event="request_rejected",
            title="Solicitud rechazada",
            body="El conductor ha rechazado tu solicitud de cupo.",
        )
    ]


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
