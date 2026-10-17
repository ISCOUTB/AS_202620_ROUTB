from datetime import date

from sqlalchemy import or_
from sqlalchemy.orm import Session, joinedload

from app.core.timezone import colombia_today
from app.modules.trips.infrastructure.models import Trip


def get_trip(db: Session, trip_id: int) -> Trip | None:
    return db.query(Trip).options(joinedload(Trip.driver)).filter(Trip.id == trip_id).first()


def get_active_trips(
    db: Session,
    origin: str | None = None,
    destination: str | None = None,
    departure_date: date | None = None,
) -> list[Trip]:
    selected_date = departure_date or colombia_today()
    query = (
        db.query(Trip)
        .options(joinedload(Trip.driver))
        .filter(Trip.status == "active", Trip.available_seats > 0)
        .filter(Trip.departure_date == selected_date)
    )
    if origin:
        query = query.filter(Trip.origin.ilike(f"%{origin.strip()}%"))
    if destination:
        query = query.filter(Trip.destination.ilike(f"%{destination.strip()}%"))
    return query.order_by(Trip.id.desc()).all()


def get_driver_trips(db: Session, driver_id: int, scope: str = "active") -> list[Trip]:
    """Rutas del conductor según el alcance.

    - ``active``: solo rutas activas (comportamiento histórico del endpoint).
    - ``history``: rutas canceladas o cuya fecha ya pasó.
    - ``all``: todas las rutas del conductor, sin filtro.
    """
    query = (
        db.query(Trip)
        .options(joinedload(Trip.driver))
        .filter(Trip.driver_id == driver_id)
    )
    if scope == "active":
        query = query.filter(Trip.status == "active")
    elif scope == "history":
        query = query.filter(
            or_(Trip.status == "cancelled", Trip.departure_date < colombia_today())
        )
    return query.order_by(Trip.id.desc()).all()
