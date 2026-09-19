from datetime import datetime
from pydantic import BaseModel, ConfigDict


class TripRequestCreate(BaseModel):
    trip_id: int


class TripRequestResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    trip_id: int
    passenger_id: int
    passenger_name: str | None = None
    passenger_phone: str | None = None
    status: str
    created_at: datetime
