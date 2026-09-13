from sqlalchemy import update
from sqlalchemy.orm import Session
from sqlalchemy.orm import joinedload

from app.modules.trips.models import Trip
from app.modules.trips.schemas import TripCreate


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


def get_trip(db: Session, trip_id: int) -> Trip | None:
    return db.query(Trip).options(joinedload(Trip.driver)).filter(Trip.id == trip_id).first()


def get_active_trips(db: Session, origin: str | None = None, destination: str | None = None) -> list[Trip]:
    query = (
        db.query(Trip)
        .options(joinedload(Trip.driver))
        .filter(Trip.status == "active", Trip.available_seats > 0)
    )
    if origin:
        query = query.filter(Trip.origin.ilike(f"%{origin.strip()}%"))
    if destination:
        query = query.filter(Trip.destination.ilike(f"%{destination.strip()}%"))
    return query.order_by(Trip.id.desc()).all()


def get_driver_trips(db: Session, driver_id: int) -> list[Trip]:
    return (
        db.query(Trip)
        .options(joinedload(Trip.driver))
        .filter(Trip.driver_id == driver_id, Trip.status == "active")
        .order_by(Trip.id.desc())
        .all()
    )


def cancel_trip(db: Session, trip_id: int, driver_id: int | None = None) -> Trip | None:
    trip = db.get(Trip, trip_id)
    if not trip:
        return None
    if driver_id is not None and trip.driver_id is not None and trip.driver_id != driver_id:
        return None
    trip.status = "cancelled"
    db.commit()
    db.refresh(trip)
    return trip


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