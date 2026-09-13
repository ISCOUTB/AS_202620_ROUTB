from sqlalchemy.orm import Session, joinedload
from fastapi import HTTPException, status

from app.modules.requests.models import TripRequest
from app.modules.trips.models import Trip


def create_request(db: Session, trip_id: int, passenger_id: int) -> TripRequest:
    trip = db.get(Trip, trip_id)
    if not trip or trip.status != "active":
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="El viaje no existe o no está activo",
        )

    if trip.driver_id == passenger_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El conductor no puede solicitar cupo en su propio viaje",
        )

    if trip.available_seats <= 0:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="No hay cupos disponibles en este viaje",
        )

    existing = (
        db.query(TripRequest)
        .filter(
            TripRequest.trip_id == trip_id,
            TripRequest.passenger_id == passenger_id,
            TripRequest.status.in_(["pending", "accepted"]),
        )
        .first()
    )
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Ya tienes una solicitud activa para este viaje",
        )

    request = TripRequest(
        trip_id=trip_id,
        passenger_id=passenger_id,
        status="pending",
    )
    db.add(request)
    db.commit()
    db.refresh(request)
    return request


def get_trip_requests(db: Session, trip_id: int) -> list[TripRequest]:
    return (
        db.query(TripRequest)
        .options(joinedload(TripRequest.passenger))
        .filter(TripRequest.trip_id == trip_id)
        .order_by(TripRequest.created_at.desc())
        .all()
    )


def accept_request(db: Session, request_id: int, driver_id: int | None = None) -> TripRequest:
    request = db.query(TripRequest).options(joinedload(TripRequest.trip)).filter(TripRequest.id == request_id).first()
    if not request:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Solicitud no encontrada")

    trip = request.trip
    if driver_id is not None and trip.driver_id is not None and trip.driver_id != driver_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="No tienes permiso para gestionar esta solicitud")

    if request.status == "accepted":
        return request

    if trip.available_seats <= 0:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="No hay cupos disponibles para aceptar más pasajeros")

    trip.available_seats -= 1
    request.status = "accepted"
    db.commit()
    db.refresh(request)
    return request


def reject_request(db: Session, request_id: int, driver_id: int | None = None) -> TripRequest:
    request = db.query(TripRequest).options(joinedload(TripRequest.trip)).filter(TripRequest.id == request_id).first()
    if not request:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Solicitud no encontrada")

    trip = request.trip
    if driver_id is not None and trip.driver_id is not None and trip.driver_id != driver_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="No tienes permiso para gestionar esta solicitud")

    if request.status == "accepted":
        # Si ya estaba aceptado y se rechaza, devolvemos el cupo
        trip.available_seats = min(trip.total_seats, trip.available_seats + 1)

    request.status = "rejected"
    db.commit()
    db.refresh(request)
    return request

