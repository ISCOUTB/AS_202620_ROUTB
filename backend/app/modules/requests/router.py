from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.modules.auth.service import get_current_user
from app.modules.requests import schemas, service
from app.modules.users.models import User

router = APIRouter()


def _to_response(req) -> schemas.TripRequestResponse:
    p_name = f"{req.passenger.name} {req.passenger.last_name}" if req.passenger else None
    p_phone = req.passenger.phone if req.passenger else None
    return schemas.TripRequestResponse(
        id=req.id,
        trip_id=req.trip_id,
        passenger_id=req.passenger_id,
        passenger_name=p_name,
        passenger_phone=p_phone,
        status=req.status,
        created_at=req.created_at,
    )


@router.post("/trips/{trip_id}", response_model=schemas.TripRequestResponse, status_code=status.HTTP_201_CREATED)
def request_seat(
    trip_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    req = service.create_request(db, trip_id=trip_id, passenger_id=current_user.id)
    return _to_response(req)


@router.get("/trips/{trip_id}", response_model=list[schemas.TripRequestResponse])
def list_trip_requests(
    trip_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    requests = service.get_trip_requests(db, trip_id=trip_id)
    return [_to_response(r) for r in requests]


@router.patch("/{request_id}/accept", response_model=schemas.TripRequestResponse)
def accept_request(
    request_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    req = service.accept_request(db, request_id=request_id, driver_id=current_user.id)
    return _to_response(req)


@router.patch("/{request_id}/reject", response_model=schemas.TripRequestResponse)
def reject_request(
    request_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    req = service.reject_request(db, request_id=request_id, driver_id=current_user.id)
    return _to_response(req)

