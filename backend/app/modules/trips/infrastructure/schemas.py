from datetime import date, datetime
from zoneinfo import ZoneInfo

from pydantic import BaseModel, ConfigDict, Field, field_validator


def _colombia_today() -> date:
    return datetime.now(ZoneInfo("America/Bogota")).date()


class DriverPoint(BaseModel):
    """Punto de partida o llegada del conductor (dirección exacta)."""

    lat: float = Field(..., ge=-90, le=90)
    lng: float = Field(..., ge=-180, le=180)
    address_text: str = Field(..., min_length=1, max_length=300)


class TripCreate(BaseModel):
    origin: str = Field(..., min_length=1)
    destination: str = Field(..., min_length=1)
    total_seats: int = Field(default=4, ge=1)
    departure_time: str | None = Field(default="7:00 AM")
    departure_date: date = Field(default_factory=_colombia_today)
    meeting_point: str = Field(default="Por coordinar", min_length=3, max_length=140)
    # Campos opcionales de la Fase 1
    direction: str | None = Field(
        default=None,
        description="'to_campus' | 'from_campus'. Nulo en viajes legados.",
    )
    driver_point: DriverPoint | None = Field(
        default=None,
        description="Coordenada exacta del punto de partida o llegada del conductor.",
    )

    @field_validator("meeting_point")
    @classmethod
    def normalize_meeting_point(cls, value: str) -> str:
        normalized = value.strip()
        if len(normalized) < 3:
            raise ValueError("El punto de encuentro debe tener al menos 3 caracteres")
        return normalized


class TripRequestSummary(BaseModel):
    id: int
    trip_id: int
    passenger_id: int
    seat_count: int = 1
    passenger_name: str | None = None
    passenger_phone: str | None = None
    status: str
    created_at: datetime


class TripResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    origin: str
    destination: str
    total_seats: int
    available_seats: int
    departure_time: str | None = "7:00 AM"
    departure_date: date = Field(default_factory=_colombia_today)
    meeting_point: str = "Por coordinar"
    status: str = "active"
    driver_id: int | None = None
    driver_name: str | None = None
    my_request_status: str | None = None
    requests: list[TripRequestSummary] = Field(default_factory=list)
