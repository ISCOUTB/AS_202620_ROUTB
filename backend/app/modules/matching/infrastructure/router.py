"""Router para endpoints del módulo de matching."""

from __future__ import annotations

from datetime import date
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.database import get_db
from app.modules.auth.infrastructure.security import get_current_user
from app.modules.matching.application.suggest_trips import suggest_trips as suggest_trips_use_case
from app.modules.matching.schemas import SuggestionItem
from app.modules.users.application import UserIdentity

router = APIRouter()


def _check_location_consent(current_user: UserIdentity) -> None:
    """Lanza 403 si el usuario no ha otorgado consentimiento de ubicación."""
    if not getattr(current_user, "location_consent_at", None):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="location_consent_required",
        )


def _validate_point_in_bbox(lat: float, lng: float) -> None:
    """Valida que un punto caiga dentro del BBOX configurado."""
    try:
        parts = [float(x) for x in settings.GEOCODE_BBOX.split(",")]
        lon_min, lat_min, lon_max, lat_max = parts
    except (ValueError, AttributeError):
        return
    if not (lon_min <= lng <= lon_max and lat_min <= lat <= lat_max):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Las coordenadas de la parada están fuera del área de operación.",
        )


@router.get(
    "/suggestions",
    response_model=list[SuggestionItem],
    responses={
        403: {"description": "location_consent_required"},
        422: {"description": "Coordenadas o parámetros inválidos"},
    },
)
def get_trip_suggestions(
    direction: Literal["to_campus", "from_campus"],
    points: Annotated[
        str,
        Query(
            description="De 1 a 4 pares lat,lng separados por ';' (ej: '10.4236,-75.5478;10.4120,-75.5310')"
        ),
    ],
    date: date,
    time: str,
    seat_count: Annotated[int, Query(ge=1, le=4)] = 1,
    relaxed: bool = False,
    db: Annotated[Session, Depends(get_db)] = None,
    current_user: Annotated[UserIdentity, Depends(get_current_user)] = None,
) -> list[SuggestionItem]:
    """Sugiere viajes compatibles ordenados por qué tan poco desvían al conductor."""
    _check_location_consent(current_user)

    # Parsear y validar puntos
    parsed_points: list[tuple[float, float]] = []
    raw_pairs = [p.strip() for p in points.split(";") if p.strip()]

    if not raw_pairs:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Debe incluir al menos un punto de parada.",
        )
    if len(raw_pairs) > 4:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Máximo 4 puntos de parada permitidos.",
        )

    for pair in raw_pairs:
        parts = pair.split(",")
        if len(parts) != 2:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Formato de coordenadas inválido en punto: '{pair}'",
            )
        try:
            pt_lat = float(parts[0].strip())
            pt_lng = float(parts[1].strip())
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Valores numéricos de lat/lng inválidos en punto: '{pair}'",
            )
        if not (-90 <= pt_lat <= 90 and -180 <= pt_lng <= 180):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Coordenadas fuera de rango en punto: '{pair}'",
            )
        _validate_point_in_bbox(pt_lat, pt_lng)
        parsed_points.append((pt_lat, pt_lng))

    return suggest_trips_use_case(
        db=db,
        passenger_id=current_user.id,
        direction=direction,
        points=parsed_points,
        trip_date=date,
        trip_time=time,
        seat_count=seat_count,
        relaxed=relaxed,
    )
