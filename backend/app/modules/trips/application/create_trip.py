from datetime import datetime
import re
from zoneinfo import ZoneInfo
from sqlalchemy.orm import Session

from app.modules.trips.infrastructure.models import Trip
from app.modules.trips.infrastructure.schemas import TripCreate


def _parse_departure_to_timestamptz(date_val, time_str: str | None) -> datetime | None:
    if not date_val or not time_str:
        return None
    time_str = time_str.strip()
    match = re.match(r"^(\d{1,2}):(\d{2})\s*(AM|PM)?$", time_str, re.IGNORECASE)
    if not match:
        return None
    hour = int(match.group(1))
    minute = int(match.group(2))
    period = match.group(3)
    if period:
        period = period.upper()
        if period == "PM" and hour < 12:
            hour += 12
        elif period == "AM" and hour == 12:
            hour = 0
    if not (0 <= hour <= 23 and 0 <= minute <= 59):
        return None
    try:
        dt = datetime(date_val.year, date_val.month, date_val.day, hour, minute)
        return dt.replace(tzinfo=ZoneInfo("America/Bogota"))
    except Exception:
        return None


def create_trip(db: Session, trip_data: TripCreate, driver_id: int | None = None) -> Trip:
    dep_time = trip_data.departure_time or "7:00 AM"
    dep_at = _parse_departure_to_timestamptz(trip_data.departure_date, dep_time)

    trip = Trip(
        origin=trip_data.origin,
        destination=trip_data.destination,
        total_seats=trip_data.total_seats,
        available_seats=trip_data.total_seats,
        departure_time=dep_time,
        departure_date=trip_data.departure_date,
        departure_at=dep_at,
        meeting_point=trip_data.meeting_point.strip(),
        driver_id=driver_id,
        status="active",
    )
    db.add(trip)
    db.commit()
    db.refresh(trip)
    return trip
