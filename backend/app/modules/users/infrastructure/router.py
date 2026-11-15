from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.modules.auth.infrastructure.security import get_current_user
from app.modules.users.application import (
    UserIdentity,
    change_user_password,
    create_user,
    delete_account,
    update_driver_vehicle,
    update_user_profile,
)
from app.modules.users.domain.exceptions import (
    ActiveCommitmentsError,
    InvalidCurrentPasswordError,
    UserAlreadyExistsError,
)
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


@router.patch(
    "/me",
    response_model=schemas.UserResponse,
    summary="Actualizar los datos personales del usuario autenticado",
    responses={
        404: {"description": "Usuario no encontrado"},
        409: {"description": "El teléfono ya está registrado"},
    },
)
def update_my_profile(
    profile: schemas.ProfileUpdate,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[UserIdentity, Depends(get_current_user)],
):
    """Actualiza nombre, apellido y teléfono del propio usuario.

    El identificador sale del token, así que no se pueden editar los datos de
    otra persona. El teléfono sigue siendo único en la base de datos.
    """
    try:
        return update_user_profile(db, current_user.id, profile)
    except UserAlreadyExistsError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=exc.message,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        )


@router.patch(
    "/me/password",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Cambiar la contraseña del usuario autenticado",
    responses={
        400: {"description": "La contraseña actual no es correcta"},
    },
)
def change_my_password(
    payload: schemas.PasswordUpdate,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[UserIdentity, Depends(get_current_user)],
):
    """Cambia la contraseña tras verificar la actual.

    No se emite un token nuevo: la sesión abierta sigue siendo válida hasta su
    vencimiento normal.
    """
    try:
        change_user_password(
            db,
            current_user.id,
            payload.current_password,
            payload.new_password,
        )
    except InvalidCurrentPasswordError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=exc.message,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        )
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.patch(
    "/me/vehicle",
    response_model=schemas.UserResponse,
    summary="Registrar o actualizar vehículo del conductor",
)
def update_my_vehicle(
    vehicle: schemas.VehicleUpdate,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[UserIdentity, Depends(get_current_user)],
):
    """Registra o actualiza el modelo, color y placa del vehículo del conductor."""
    try:
        return update_driver_vehicle(db, current_user.id, vehicle)
    except PermissionError as exc:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=str(exc),
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        )


@router.delete(
    "/me",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Eliminar la cuenta del usuario autenticado",
    responses={
        409: {
            "description": (
                "La cuenta tiene rutas activas o solicitudes pendientes/"
                "aceptadas."
            )
        }
    },
)
def delete_my_account(
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[UserIdentity, Depends(get_current_user)],
):
    """Borra la cuenta y sus datos personales.

    Se rechaza con 409 si el usuario todavía tiene compromisos activos para no
    dejar viajes ni cupos huérfanos. Los viajes históricos del conductor se
    conservan anonimizados por la clave foránea ``ON DELETE SET NULL``.
    """
    try:
        delete_account(db, current_user.id)
    except ActiveCommitmentsError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=exc.message,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        )
    return Response(status_code=status.HTTP_204_NO_CONTENT)
