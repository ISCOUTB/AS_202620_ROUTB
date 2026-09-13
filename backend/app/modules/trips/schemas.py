from pydantic import BaseModel, ConfigDict, Field


class TripCreate(BaseModel):
    origin: str = Field(..., min_length=1)
    destination: str = Field(..., min_length=1)
    total_seats: int = Field(default=4, ge=1)
    departure_time: str | None = Field(default="7:00 AM")


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