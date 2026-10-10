from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, Field


class SuggestionItem(BaseModel):
    trip_id: int
    driver_id: int
    driver_name: str
    driver_phone: str | None = None
    origin: str
    destination: str
    direction: str
    departure_date: date
    departure_time: str
    departure_at: datetime | None = None
    eta_pickup: datetime | None = None
    detour_minutes: float = Field(..., description="Desvío en minutos para el conductor")
    walk_distance_m: float = Field(..., description="Distancia al punto de la ruta en metros")
    score: float = Field(..., description="Puntuación de compatibilidad (menor = mejor)")
    available_seats: int
    total_seats: int
    degraded: bool = False
