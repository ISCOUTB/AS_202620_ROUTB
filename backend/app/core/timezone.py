from datetime import date, datetime, timedelta, timezone
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

try:
    COLOMBIA_TZ = ZoneInfo("America/Bogota")
except (ZoneInfoNotFoundError, ModuleNotFoundError, Exception):
    COLOMBIA_TZ = timezone(timedelta(hours=-5))


def get_colombia_tz():
    return COLOMBIA_TZ


def colombia_now() -> datetime:
    return datetime.now(COLOMBIA_TZ)


def colombia_today() -> date:
    return colombia_now().date()
