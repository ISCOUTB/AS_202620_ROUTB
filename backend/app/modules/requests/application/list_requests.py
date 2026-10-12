from sqlalchemy.orm import Session, joinedload

from app.modules.requests.application.expire_requests import expire_stale_requests
from app.modules.requests.domain.exceptions import UnauthorizedRequestActionError
from app.modules.requests.infrastructure.models import TripRequest
from app.modules.trips.infrastructure.models import Trip


def get_trip_requests(
    db: Session, trip_id: int, driver_id: int | None = None
) -> list[TripRequest]:
    if driver_id is not None:
        owner_id = db.query(Trip.driver_id).filter(Trip.id == trip_id).scalar()
        if owner_id != driver_id:
            raise UnauthorizedRequestActionError(
                "Solo el conductor del viaje puede ver sus solicitudes"
            )
    expire_stale_requests(db)
    return (
        db.query(TripRequest)
        .options(joinedload(TripRequest.passenger))
        .filter(TripRequest.trip_id == trip_id)
        .order_by(TripRequest.created_at.desc())
        .all()
    )


def get_passenger_requests(db: Session, passenger_id: int) -> list[TripRequest]:
    """Solicitudes del pasajero, con el viaje relacionado cargado.

    Es la unica via para seguir viendo un viaje propio cuando este deja de
    salir en ``GET /trips/``, que filtra por ``available_seats > 0``: al ocupar
    el ultimo cupo el viaje desaparece del listado, pero la solicitud sigue
    viva y hay que poder seguir viéndola.
    """
    expire_stale_requests(db)
    return (
        db.query(TripRequest)
        .options(joinedload(TripRequest.trip))
        .filter(TripRequest.passenger_id == passenger_id)
        .order_by(TripRequest.created_at.desc(), TripRequest.id.desc())
        .all()
    )
