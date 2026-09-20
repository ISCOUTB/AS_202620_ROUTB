from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.modules.auth.infrastructure.security import get_current_user, get_optional_current_user
from app.modules.trips.application.cancel_trip import cancel_trip as cancel_trip_use_case
from app.modules.trips.application.create_trip import create_trip as create_trip_use_case
from app.modules.trips.application.get_trips import (
    get_active_trips as get_active_trips_use_case,
    get_driver_trips as get_driver_trips_use_case,
    get_trip as get_trip_use_case,
)
from app.modules.trips.application.reserve_seat import reserve_seat as reserve_seat_use_case
from app.modules.trips.domain.exceptions import TripNotAuthorizedError, TripNotFoundError
from app.modules.trips.infrastructure import schemas
from app.modules.users.infrastructure.models import User

router = APIRouter()


def _to_response(trip) -> schemas.TripResponse:
    driver_name = f"{trip.driver.name} {trip.driver.last_name}" if trip.driver else None
    return schemas.TripResponse(
        id=trip.id,
        origin=trip.origin,
        destination=trip.destination,
        total_seats=trip.total_seats,
        available_seats=trip.available_seats,
        departure_time=trip.departure_time,
        status=trip.status,
        driver_id=trip.driver_id,
        driver_name=driver_name,
    )


@router.post("/", response_model=schemas.TripResponse, status_code=status.HTTP_201_CREATED)
def create_trip(
    trip: schemas.TripCreate,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User | None, Depends(get_optional_current_user)] = None,
):
    driver_id = current_user.id if current_user else None
    created = create_trip_use_case(db, trip, driver_id=driver_id)
    return _to_response(created)


@router.get("/", response_model=list[schemas.TripResponse])
def get_active_trips(
    db: Annotated[Session, Depends(get_db)],
    origin: str | None = Query(None),
    destination: str | None = Query(None),
):
    trips = get_active_trips_use_case(db, origin=origin, destination=destination)
    return [_to_response(t) for t in trips]


@router.get("/my-trips", response_model=list[schemas.TripResponse])
def get_my_trips(
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    trips = get_driver_trips_use_case(db, driver_id=current_user.id)
    return [_to_response(t) for t in trips]


@router.get("/{trip_id}", response_model=schemas.TripResponse)
def get_trip(
    trip_id: int,
    db: Annotated[Session, Depends(get_db)],
):
    trip = get_trip_use_case(db, trip_id)
    if trip is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Trip not found")
    return _to_response(trip)


@router.patch("/{trip_id}/cancel", response_model=schemas.TripResponse)
def cancel_trip(
    trip_id: int,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User | None, Depends(get_optional_current_user)] = None,
):
    driver_id = current_user.id if current_user else None
    try:
        trip = cancel_trip_use_case(db, trip_id, driver_id=driver_id)
    except (TripNotFoundError, TripNotAuthorizedError):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Viaje no encontrado o no autorizado",
        )
    return _to_response(trip)


@router.post("/{trip_id}/reservations", response_model=schemas.TripResponse)
def reserve_trip_seat(
    trip_id: int,
    db: Annotated[Session, Depends(get_db)],
):
    trip = reserve_seat_use_case(db, trip_id)
    if trip is None:
        if get_trip_use_case(db, trip_id) is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Trip not found")
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="No seats available")
    return _to_response(trip)
