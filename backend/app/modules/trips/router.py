from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.modules.auth.service import get_current_user, get_optional_current_user
from app.modules.trips import schemas, service
from app.modules.users.models import User

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
    db: Session = Depends(get_db),
    current_user: User | None = Depends(get_optional_current_user),
):
    driver_id = current_user.id if current_user else None
    created = service.create_trip(db, trip, driver_id=driver_id)
    return _to_response(created)


@router.get("/", response_model=list[schemas.TripResponse])
def get_active_trips(
    origin: str | None = Query(None),
    destination: str | None = Query(None),
    db: Session = Depends(get_db),
):
    trips = service.get_active_trips(db, origin=origin, destination=destination)
    return [_to_response(t) for t in trips]


@router.get("/my-trips", response_model=list[schemas.TripResponse])
def get_my_trips(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    trips = service.get_driver_trips(db, driver_id=current_user.id)
    return [_to_response(t) for t in trips]


@router.get("/{trip_id}", response_model=schemas.TripResponse)
def get_trip(trip_id: int, db: Session = Depends(get_db)):
    trip = service.get_trip(db, trip_id)
    if trip is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Trip not found")
    return _to_response(trip)


@router.patch("/{trip_id}/cancel", response_model=schemas.TripResponse)
def cancel_trip(
    trip_id: int,
    db: Session = Depends(get_db),
    current_user: User | None = Depends(get_optional_current_user),
):
    driver_id = current_user.id if current_user else None
    trip = service.cancel_trip(db, trip_id, driver_id=driver_id)
    if trip is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Viaje no encontrado o no autorizado")
    return _to_response(trip)


@router.post("/{trip_id}/reservations", response_model=schemas.TripResponse)
def reserve_trip_seat(trip_id: int, db: Session = Depends(get_db)):
    trip = service.reserve_seat(db, trip_id)
    if trip is None:
        if service.get_trip(db, trip_id) is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Trip not found")
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="No seats available")
    return _to_response(trip)