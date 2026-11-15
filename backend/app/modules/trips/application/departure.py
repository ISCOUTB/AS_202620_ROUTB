"""Cálculo de la hora de salida de un viaje y su vencimiento."""

from datetime import date, datetime, time
import re

from app.core.timezone import colombia_now, get_colombia_tz

_DEPARTURE_PATTERN = re.compile(r"^(\d{1,2}):(\d{2})\s*(AM|PM)?$", re.IGNORECASE)


def parse_departure_to_timestamptz(
    date_val: date | None, time_str: str | None
) -> datetime | None:
    """Interpreta la fecha y la hora de texto de un viaje.

    Devuelve la marca de tiempo en la zona horaria de Colombia, o ``None`` si
    falta algún dato o el texto no tiene un formato válido.
    """
    if not date_val or not time_str:
        return None
    time_str = time_str.strip()
    match = _DEPARTURE_PATTERN.match(time_str)
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
        return dt.replace(tzinfo=get_colombia_tz())
    except Exception:
        return None


def trip_departure_at(
    *,
    departure_at: datetime | None,
    departure_date: date | None,
    departure_time: str | None,
) -> datetime | None:
    """Hora de salida del viaje, con respaldo en la fecha y el texto.

    Si no hay una hora interpretable pero sí fecha, se usa el final de ese día
    como último momento seguro. Solo así un viaje sin hora no se descarta antes
    de tiempo.
    """
    if departure_at is not None:
        return departure_at
    departure = parse_departure_to_timestamptz(departure_date, departure_time or "")
    if departure is None and departure_date is not None:
        departure = datetime.combine(
            departure_date, time.max, tzinfo=get_colombia_tz()
        )
    return departure


def trip_has_departed(
    *,
    departure_at: datetime | None,
    departure_date: date | None,
    departure_time: str | None,
    now: datetime | None = None,
) -> bool:
    """``True`` si el viaje ya salió y no admite solicitudes nuevas."""
    departure = trip_departure_at(
        departure_at=departure_at,
        departure_date=departure_date,
        departure_time=departure_time,
    )
    if departure is None:
        return False
    return departure <= (now or colombia_now())
