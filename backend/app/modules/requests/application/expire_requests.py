"""Vencimiento perezoso de solicitudes cuya hora de salida ya pasó."""

from sqlalchemy.orm import Session, joinedload

from app.core.timezone import colombia_now
from app.modules.requests.infrastructure.models import TripRequest
from app.modules.trips.application.departure import trip_departure_at


def expire_stale_requests(db: Session, request_id: int | None = None) -> int:
    query = (
        db.query(TripRequest)
        .options(joinedload(TripRequest.trip))
        .filter(TripRequest.status == "pending")
    )
    if request_id is not None:
        query = query.filter(TripRequest.id == request_id)

    now = colombia_now()
    expired = 0
    for request in query.all():
        trip = request.trip
        if trip is None:
            continue
        departure = trip_departure_at(
            departure_at=trip.departure_at,
            departure_date=trip.departure_date,
            departure_time=trip.departure_time,
        )
        if departure is not None and departure <= now:
            request.status = "expired"
            expired += 1
    if expired:
        db.commit()
    return expired
