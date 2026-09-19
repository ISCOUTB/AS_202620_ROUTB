from sqlalchemy.orm import Session

from app.modules.trips.infrastructure.models import Trip
from app.modules.trips.infrastructure.schemas import TripCreate


def create_trip(db: Session, trip_data: TripCreate, driver_id: int | None = None) -> Trip:
    trip = Trip(
        origin=trip_data.origin,
        destination=trip_data.destination,
        total_seats=trip_data.total_seats,
        available_seats=trip_data.total_seats,
        departure_time=trip_data.departure_time or "7:00 AM",
        driver_id=driver_id,
        status="active",
    )
    db.add(trip)
    db.commit()
    db.refresh(trip)
    return trip
