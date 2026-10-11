from datetime import date, datetime
from pydantic import BaseModel, ConfigDict, Field, model_validator


class RequestStopCreate(BaseModel):
    seats: int = Field(ge=1, le=4)
    place_type: str = Field(pattern="^(door|meeting_point)$")
    lat: float = Field(ge=-90, le=90)
    lng: float = Field(ge=-180, le=180)
    address_text: str = Field(min_length=1, max_length=500)


class TripRequestCreate(BaseModel):
    seat_count: int = Field(default=1, ge=1, le=4)
    requested_at: datetime | None = None
    stops: list[RequestStopCreate] = Field(default_factory=list, max_length=4)

    @model_validator(mode="after")
    def validate_stop_seats(self):
        if self.stops and sum(stop.seats for stop in self.stops) != self.seat_count:
            raise ValueError("La suma de cupos de las paradas debe coincidir con seat_count")
        return self


class RequestStopResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    seats: int
    place_type: str
    address_text: str
    stop_seq: int | None = None
    eta_estimated: datetime | None = None


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
    stops: list[RequestStopResponse] = []

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
    total_seats: int
    available_seats: int
    trip_status: str
    driver_name: str | None = None
    driver_phone: str | None = None
    stops: list[RequestStopResponse] = []
