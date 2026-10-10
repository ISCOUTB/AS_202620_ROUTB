"""Router de notificaciones: gestión de tokens de dispositivo."""

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.modules.auth.infrastructure.security import get_current_user
from app.modules.notifications.application.manage_device_token import (
    delete_token,
    upsert_token,
)
from app.modules.notifications.infrastructure.schemas import (
    DeviceTokenResponse,
    DeviceTokenUpsert,
)
from app.modules.users.application import UserIdentity

router = APIRouter()


@router.put(
    "/device-token",
    response_model=DeviceTokenResponse,
    status_code=status.HTTP_200_OK,
    summary="Registrar o actualizar token de dispositivo",
    responses={
        200: {"description": "Token registrado o actualizado correctamente"},
        422: {"description": "Datos inválidos"},
    },
)
def register_device_token(
    payload: DeviceTokenUpsert,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[UserIdentity, Depends(get_current_user)],
) -> DeviceTokenResponse:
    """Registra o renueva el token FCM del dispositivo del usuario autenticado.

    Si el token ya existe se actualiza `last_seen_at`; si pertenecía a otra
    cuenta se reasigna al usuario actual.
    """
    token_row = upsert_token(
        db,
        user_id=current_user.id,
        device_token=payload.device_token,
        platform=payload.platform,
    )
    return DeviceTokenResponse.model_validate(token_row)


@router.delete(
    "/device-token/{token}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Eliminar token de dispositivo",
    responses={
        204: {"description": "Token eliminado"},
        404: {"description": "Token no encontrado para este usuario"},
    },
)
def remove_device_token(
    token: str,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[UserIdentity, Depends(get_current_user)],
) -> Response:
    """Elimina un token FCM registrado por el usuario autenticado."""
    deleted = delete_token(db, device_token=token, user_id=current_user.id)
    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Token no encontrado para este usuario",
        )
    return Response(status_code=status.HTTP_204_NO_CONTENT)
