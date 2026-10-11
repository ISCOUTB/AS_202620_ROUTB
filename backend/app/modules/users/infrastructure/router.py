from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.modules.auth.infrastructure.security import get_current_user
from app.modules.users.application import UserIdentity, create_user, get_users
from app.modules.users.application.location_consent import (
    grant_location_consent,
    revoke_location_consent,
)
from app.modules.users.domain.exceptions import UserAlreadyExistsError
from app.modules.users.infrastructure import schemas

router = APIRouter()


@router.post("/", response_model=schemas.UserResponse)
def register_basic_user(
    user: schemas.UserCreate,
    db: Annotated[Session, Depends(get_db)],
):
    try:
        return create_user(db=db, user_data=user)
    except UserAlreadyExistsError as e:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=e.message,
        )


@router.get("/")
def list_users(db: Annotated[Session, Depends(get_db)]):
    return get_users(db=db)


@router.post(
    "/me/location-consent",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Otorgar consentimiento de ubicación",
)
def post_location_consent(
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[UserIdentity, Depends(get_current_user)],
):
    """Registra que el usuario acepta el tratamiento de su ubicación.

    Persiste ``location_consent_at`` en la base de datos.
    """
    grant_location_consent(db, current_user.id)


@router.delete(
    "/me/location-consent",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Revocar consentimiento de ubicación",
)
def delete_location_consent(
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[UserIdentity, Depends(get_current_user)],
):
    """Revoca el consentimiento de ubicación del usuario.

    Cancela las solicitudes pendientes y borra las paradas almacenadas.
    """
    revoke_location_consent(db, current_user.id)
