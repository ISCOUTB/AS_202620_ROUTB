from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.modules.trips import schemas, service

router = APIRouter()


@router.post("/", response_model=schemas.TripResponse, status_code=status.HTTP_201_CREATED)
def create_trip(trip: schemas.TripCreate, db: Session = Depends(get_db)):
    return service.create_trip(db, trip)


@router.get("/{trip_id}", response_model=schemas.TripResponse)
def get_trip(trip_id: int, db: Session = Depends(get_db)):
    trip = service.get_trip(db, trip_id)
    if trip is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Trip not found")
    return trip


@router.post("/{trip_id}/reservations", response_model=schemas.TripResponse)
def reserve_trip_seat(trip_id: int, db: Session = Depends(get_db)):
    trip = service.reserve_seat(db, trip_id)
    if trip is None:
        if service.get_trip(db, trip_id) is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Trip not found")
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="No seats available")
    return trip