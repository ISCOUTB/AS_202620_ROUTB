"""Public application operations used by requests to inspect and adjust seats."""

from dataclasses import dataclass

from sqlalchemy import select, update
from sqlalchemy.orm import Session

from app.modules.trips.infrastructure.models import Trip


@dataclass(frozen=True)
class TripRequestContext:
    trip_id: int
    driver_id: int | None
    status: str
    available_seats: int


def get_trip_request_context(db: Session, trip_id: int) -> TripRequestContext | None:
    row = db.execute(
        select(Trip.id, Trip.driver_id, Trip.status, Trip.available_seats).where(
            Trip.id == trip_id
        )
    ).one_or_none()
    if row is None:
        return None
    return TripRequestContext(
        trip_id=row.id,
        driver_id=row.driver_id,
        status=row.status,
        available_seats=row.available_seats,
    )


def reserve_request_seats(db: Session, trip_id: int, seat_count: int) -> bool:
    """Atomically reserve all requested seats; the caller owns the transaction."""
    result = db.execute(
        update(Trip)
        .where(
            Trip.id == trip_id,
            Trip.status == "active",
            Trip.available_seats >= seat_count,
        )
        .values(available_seats=Trip.available_seats - seat_count)
        .execution_options(synchronize_session=False)
    )
    return result.rowcount == 1


def release_request_seats(db: Session, trip_id: int, seat_count: int) -> bool:
    """Atomically return seats without exceeding the trip's original capacity."""
    result = db.execute(
        update(Trip)
        .where(
            Trip.id == trip_id,
            Trip.available_seats + seat_count <= Trip.total_seats,
        )
        .values(available_seats=Trip.available_seats + seat_count)
        .execution_options(synchronize_session=False)
    )
    return result.rowcount == 1
