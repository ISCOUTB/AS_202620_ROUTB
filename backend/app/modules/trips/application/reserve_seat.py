from sqlalchemy import update
from sqlalchemy.orm import Session

from app.modules.trips.infrastructure.models import Trip


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
