from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.modules.auth.infrastructure.security import get_current_user
from app.modules.requests.application.create_request import create_request as create_request_use_case
from app.modules.requests.application.list_requests import get_trip_requests as get_trip_requests_use_case
from app.modules.requests.application.manage_request import (
    accept_request as accept_request_use_case,
    reject_request as reject_request_use_case,
)
from app.modules.requests.domain.exceptions import (
    ActiveRequestAlreadyExistsError,
    DriverCannotRequestError,
    NoAvailableSeatsError,
    NoSeatsToAcceptError,
    TripNotActiveError,
    TripRequestNotFoundError,
    UnauthorizedRequestActionError,
)
from app.modules.requests.infrastructure import schemas
from app.modules.users.infrastructure.models import User

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
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    try:
        req = create_request_use_case(db, trip_id=trip_id, passenger_id=current_user.id)
        return _to_response(req)
    except TripNotActiveError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=e.message)
    except DriverCannotRequestError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=e.message)
    except NoAvailableSeatsError as e:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=e.message)
    except ActiveRequestAlreadyExistsError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=e.message)


@router.get("/trips/{trip_id}", response_model=list[schemas.TripRequestResponse])
def list_trip_requests(
    trip_id: int,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    requests = get_trip_requests_use_case(db, trip_id=trip_id)
    return [_to_response(r) for r in requests]


@router.patch("/{request_id}/accept", response_model=schemas.TripRequestResponse)
def accept_request(
    request_id: int,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    try:
        req = accept_request_use_case(db, request_id=request_id, driver_id=current_user.id)
        return _to_response(req)
    except TripRequestNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=e.message)
    except UnauthorizedRequestActionError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=e.message)
    except NoSeatsToAcceptError as e:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=e.message)


@router.patch("/{request_id}/reject", response_model=schemas.TripRequestResponse)
def reject_request(
    request_id: int,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    try:
        req = reject_request_use_case(db, request_id=request_id, driver_id=current_user.id)
        return _to_response(req)
    except TripRequestNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=e.message)
    except UnauthorizedRequestActionError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=e.message)
