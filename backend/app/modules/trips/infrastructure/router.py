from typing import Annotated
from app.modules.requests.infrastructure.router import _to_response as _to_request_response
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


def _current_user_request_status(trip, current_user_id: int | None) -> str | None:
    if current_user_id is None or not hasattr(trip, "requests") or not trip.requests:
        return None

    for request in trip.requests:
        if request.passenger_id == current_user_id:
            return request.status
    return None


def _to_response(trip, current_user_id: int | None = None) -> schemas.TripResponse:
    driver_name = f"{trip.driver.name} {trip.driver.last_name}" if trip.driver else None

    trip_requests = (
        [_to_request_response(r) for r in trip.requests]
        if hasattr(trip, "requests") and trip.requests
        else []
    )

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
        requests=trip_requests,
        my_request_status=_current_user_request_status(trip, current_user_id),
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
    current_user: Annotated[User | None, Depends(get_optional_current_user)] = None,
):
    trips = get_active_trips_use_case(db, origin=origin, destination=destination)
    current_user_id = current_user.id if current_user else None
    return [_to_response(t, current_user_id=current_user_id) for t in trips]


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
    current_user: Annotated[User | None, Depends(get_optional_current_user)] = None,
):
    trip = get_trip_use_case(db, trip_id)
    if trip is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Trip not found")
    return _to_response(trip, current_user_id=current_user.id if current_user else None)


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
    return _to_response(trip, current_user_id=driver_id)


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
