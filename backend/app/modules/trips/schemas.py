from pydantic import BaseModel, ConfigDict, Field


class TripCreate(BaseModel):
    origin: str = Field(..., min_length=1)
    destination: str = Field(..., min_length=1)
    total_seats: int = Field(..., ge=1)


class TripResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    origin: str
    destination: str
    total_seats: int
    available_seats: int