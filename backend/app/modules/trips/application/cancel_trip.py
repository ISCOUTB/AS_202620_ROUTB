from sqlalchemy.orm import Session

from app.modules.trips.domain.exceptions import TripNotAuthorizedError, TripNotFoundError
from app.modules.trips.infrastructure.models import Trip


def cancel_trip(db: Session, trip_id: int, driver_id: int | None = None) -> Trip:
    trip = db.get(Trip, trip_id)
    if not trip:
        raise TripNotFoundError("Viaje no encontrado")
    if driver_id is not None and trip.driver_id is not None and trip.driver_id != driver_id:
        raise TripNotAuthorizedError("No autorizado para cancelar este viaje")
    trip.status = "cancelled"
    db.commit()
    db.refresh(trip)
    return trip
