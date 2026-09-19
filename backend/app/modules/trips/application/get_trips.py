from sqlalchemy.orm import Session, joinedload

from app.modules.trips.infrastructure.models import Trip


def get_trip(db: Session, trip_id: int) -> Trip | None:
    return db.query(Trip).options(joinedload(Trip.driver)).filter(Trip.id == trip_id).first()


def get_active_trips(
    db: Session, origin: str | None = None, destination: str | None = None
) -> list[Trip]:
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
