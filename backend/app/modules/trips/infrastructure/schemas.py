from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class TripCreate(BaseModel):
    origin: str = Field(..., min_length=1)
    destination: str = Field(..., min_length=1)
    total_seats: int = Field(default=4, ge=1)
    departure_time: str | None = Field(default="7:00 AM")


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
    status: str = "active"
    driver_id: int | None = None
    driver_name: str | None = None
    my_request_status: str | None = None
    requests: list[TripRequestSummary] = Field(default_factory=list)
