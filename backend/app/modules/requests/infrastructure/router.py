from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.modules.auth.infrastructure.security import get_current_user
from app.modules.requests.application.create_request import create_request as create_request_use_case
from app.modules.requests.application.list_requests import (
    get_passenger_requests as get_passenger_requests_use_case,
)
from app.modules.requests.application.list_requests import get_trip_requests as get_trip_requests_use_case
from app.modules.requests.application.manage_request import (
    accept_request as accept_request_use_case,
    reject_request as reject_request_use_case,
    withdraw_request as withdraw_request_use_case,
)
from app.modules.requests.domain.exceptions import (
    ActiveRequestAlreadyExistsError,
    DriverCannotRequestError,
    InvalidRequestStateError,
    NoAvailableSeatsError,
    NoSeatsToAcceptError,
    TripNotActiveError,
    TripRequestNotFoundError,
    UnauthorizedRequestActionError,
)
from app.modules.requests.infrastructure import schemas
from app.modules.users.application import UserIdentity

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
        seat_count=req.seat_count,
        created_at=req.created_at,
    )


def _to_my_response(req) -> schemas.MyRequestResponse:
    trip = req.trip
    driver = trip.driver if trip else None
    return schemas.MyRequestResponse(
        id=req.id,
        seat_count=req.seat_count,
        status=req.status,
        created_at=req.created_at,
        trip_id=req.trip_id,
        origin=trip.origin if trip else "",
        destination=trip.destination if trip else "",
        departure_time=trip.departure_time if trip else None,
        total_seats=trip.total_seats if trip else 0,
        available_seats=trip.available_seats if trip else 0,
        trip_status=trip.status if trip else "cancelled",
        driver_name=f"{driver.name} {driver.last_name}" if driver else None,
        driver_phone=driver.phone if driver else None,
    )


@router.post("/trips/{trip_id}", response_model=schemas.TripRequestResponse, status_code=status.HTTP_201_CREATED)
def request_seat(
    trip_id: int,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[UserIdentity, Depends(get_current_user)],
    payload: schemas.TripRequestCreate | None = None,
):
    try:
        req = create_request_use_case(
            db,
            trip_id=trip_id,
            passenger_id=current_user.id,
            seat_count=payload.seat_count if payload is not None else 1,
        )
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
    current_user: Annotated[UserIdentity, Depends(get_current_user)],
):
    requests = get_trip_requests_use_case(db, trip_id=trip_id)
    return [_to_response(r) for r in requests]


@router.patch("/{request_id}/accept", response_model=schemas.TripRequestResponse)
def accept_request(
    request_id: int,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[UserIdentity, Depends(get_current_user)],
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
    except InvalidRequestStateError as e:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=e.message)


@router.patch("/{request_id}/reject", response_model=schemas.TripRequestResponse)
def reject_request(
    request_id: int,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[UserIdentity, Depends(get_current_user)],
):
    try:
        req = reject_request_use_case(db, request_id=request_id, driver_id=current_user.id)
        return _to_response(req)
    except TripRequestNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=e.message)
    except UnauthorizedRequestActionError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=e.message)
    except InvalidRequestStateError as e:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=e.message)


@router.get("/me", response_model=list[schemas.MyRequestResponse])
def my_requests(
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[UserIdentity, Depends(get_current_user)],
):
    """Solicitudes del pasajero que entra, con los datos de su viaje.

    Es la via que sobrevive a que el viaje se llene: ``GET /trips/`` solo
    devuelve los que tienen cupo libre, asi que un pasajero con el ultimo
    cupo confirmado no lo veria ahi.
    """
    requests = get_passenger_requests_use_case(db, passenger_id=current_user.id)
    return [_to_my_response(r) for r in requests]


@router.delete("/{request_id}", status_code=status.HTTP_204_NO_CONTENT)
def withdraw_request(
    request_id: int,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
):
    """Retira la solicitud del pasajero que entra y libera el cupo ocupado."""
    try:
        withdraw_request_use_case(db, request_id=request_id, passenger_id=current_user.id)
    except TripRequestNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=e.message)
    except UnauthorizedRequestActionError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=e.message)
    except InvalidRequestStateError as e:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=e.message)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
