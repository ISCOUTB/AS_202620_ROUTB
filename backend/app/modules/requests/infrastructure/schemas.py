from datetime import date, datetime
from pydantic import BaseModel, ConfigDict, Field


class TripRequestCreate(BaseModel):
    seat_count: int = Field(default=1, ge=1, le=4)


class TripRequestResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

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
    departure_time: str
    status: str
    driver_id: int | None = None
    driver_name: str | None = None
    requests: list[TripRequestResponse] = []


class MyRequestResponse(BaseModel):
    """Solicitud propia del pasajero con una foto del viaje.

    Se expone plana y no anidada porque el pasajero la lee desde su telefono y
    necesita solo los datos que caben en su pantalla. El viaje viaja dentro
    porque ``GET /trips/`` deja de devolverlo cuando se ocupa el ultimo cupo.
    """

    model_config = ConfigDict(from_attributes=True)

    id: int
    seat_count: int = 1
    status: str
    created_at: datetime
    trip_id: int
    origin: str
    destination: str
    departure_time: str | None = None
    departure_date: date | None = None
    meeting_point: str = "Por coordinar"
    fare_per_seat: int = 0
    total_seats: int
    available_seats: int
    trip_status: str
    driver_name: str | None = None
    driver_phone: str | None = None
