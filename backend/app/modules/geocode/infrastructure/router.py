"""Router del módulo de geocodificación.

Expone:
  GET /geocode/search?q=<dirección>

Requiere autenticación JWT y que el usuario haya dado consentimiento de
ubicación (``location_consent_at`` no nulo). Aplica rate-limit de
30 req/min por usuario.
"""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.database import get_db
from app.modules.auth.infrastructure.security import get_current_user
from app.modules.geocode.application.rate_limit import geocode_search_rate_limit
from app.modules.users.application import UserIdentity
from app.shared.geocode.service import GeocodeUnavailable, geocode

router = APIRouter()


def _check_location_consent(current_user: UserIdentity) -> None:
    """Lanza 403 si el usuario no ha dado consentimiento de ubicación."""
    if not getattr(current_user, "location_consent_at", None):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="location_consent_required",
        )


def _validate_bbox(lat: float | None, lng: float | None) -> None:
    """Valida que las coordenadas estén dentro del bounding box configurado."""
    if lat is None or lng is None:
        return
    try:
        parts = [float(x) for x in settings.GEOCODE_BBOX.split(",")]
        lon_min, lat_min, lon_max, lat_max = parts
    except (ValueError, AttributeError):
        return
    if not (lon_min <= lng <= lon_max and lat_min <= lat <= lat_max):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Las coordenadas están fuera del área de operación.",
        )


@router.get(
    "/search",
    responses={
        403: {"description": "location_consent_required"},
        429: {"description": "geocode_rate_limit_exceeded"},
        503: {"description": "geocode_unavailable"},
    },
)
def geocode_search(
    q: Annotated[str, Query(min_length=2, max_length=200, description="Dirección a buscar")],
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[UserIdentity, Depends(get_current_user)],
) -> list[dict]:
    """Busca una dirección y devuelve hasta 5 resultados geocodificados.

    Requiere consentimiento de ubicación. Rate-limit: 30 req/min por usuario.

    Respuestas:
    - **200**: lista de resultados (puede ser vacía).
    - **403**: ``location_consent_required`` si falta el consentimiento.
    - **503**: si fallan Photon y Nominatim.
    - **429**: si se exceden 30 búsquedas en un minuto.
    """
    _check_location_consent(current_user)
    if not geocode_search_rate_limit.allow(current_user.id):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="geocode_rate_limit_exceeded",
        )

    try:
        results = geocode(db, q)
    except GeocodeUnavailable:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="geocode_unavailable",
        )

    return results
