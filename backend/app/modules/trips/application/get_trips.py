from datetime import date

from sqlalchemy import or_
from sqlalchemy.orm import Session, joinedload, selectinload

from app.core.timezone import colombia_now, colombia_today
from app.modules.trips.application.departure import trip_has_departed
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

    # Un viaje activo con cupo deja de ser ofertable en cuanto pasa su hora de
    # salida. El filtro se hace aquí y no solo en SQL para cubrir los viajes
    # legados que guardan la hora únicamente en `departure_time`.
    now = colombia_now()
    return [
        trip
        for trip in query.order_by(Trip.id.desc()).all()
        if not trip_has_departed(
            departure_at=trip.departure_at,
            departure_date=trip.departure_date,
            departure_time=trip.departure_time,
            now=now,
        )
    ]


def get_driver_trips(db: Session, driver_id: int, scope: str = "active") -> list[Trip]:
    """Rutas del conductor según el alcance.

    - ``active``: solo rutas activas (comportamiento histórico del endpoint).
    - ``history``: rutas canceladas o cuya fecha ya pasó.
    - ``all``: todas las rutas del conductor, sin filtro.
    """
    query = (
        db.query(Trip)
        .options(joinedload(Trip.driver), selectinload(Trip.requests))
        .filter(Trip.driver_id == driver_id)
    )
    if scope == "active":
        query = query.filter(Trip.status == "active")
    elif scope == "history":
        query = query.filter(
            or_(Trip.status == "cancelled", Trip.departure_date < colombia_today())
        )
    return query.order_by(Trip.id.desc()).all()
