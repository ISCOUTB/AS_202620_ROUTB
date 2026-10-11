"""Vencimiento perezoso de solicitudes cuya hora de salida ya pasó."""

from datetime import datetime, time

from sqlalchemy.orm import Session, joinedload

from app.core.timezone import colombia_now
from app.modules.requests.infrastructure.models import TripRequest
from app.modules.trips.application.create_trip import _parse_departure_to_timestamptz


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
        departure = trip.departure_at or _parse_departure_to_timestamptz(
            trip.departure_date, trip.departure_time or ""
        )
        if departure is None and trip.departure_date is not None:
            departure = datetime.combine(
                trip.departure_date, time.max, tzinfo=now.tzinfo
            )
        if departure <= now:
            request.status = "expired"
            expired += 1
    if expired:
        db.commit()
    return expired
