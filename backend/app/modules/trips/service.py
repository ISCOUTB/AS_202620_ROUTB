from sqlalchemy import update
from sqlalchemy.orm import Session

from app.modules.trips.models import Trip
from app.modules.trips.schemas import TripCreate


def create_trip(db: Session, trip_data: TripCreate) -> Trip:
    trip = Trip(
        origin=trip_data.origin,
        destination=trip_data.destination,
        total_seats=trip_data.total_seats,
        available_seats=trip_data.total_seats,
    )
    db.add(trip)
    db.commit()
    db.refresh(trip)
    return trip


def get_trip(db: Session, trip_id: int) -> Trip | None:
    return db.get(Trip, trip_id)


def reserve_seat(db: Session, trip_id: int) -> Trip | None:
    result = db.execute(
        update(Trip)
        .where(Trip.id == trip_id, Trip.available_seats > 0)
        .values(available_seats=Trip.available_seats - 1)
    )
    if result.rowcount != 1:
        db.rollback()
        return None

    db.commit()
    return db.get(Trip, trip_id)