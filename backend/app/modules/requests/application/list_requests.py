from sqlalchemy.orm import Session, joinedload

from app.modules.requests.infrastructure.models import TripRequest


def get_trip_requests(db: Session, trip_id: int) -> list[TripRequest]:
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
    return (
        db.query(TripRequest)
        .options(joinedload(TripRequest.trip))
        .filter(TripRequest.passenger_id == passenger_id)
        .order_by(TripRequest.created_at.desc(), TripRequest.id.desc())
        .all()
    )
