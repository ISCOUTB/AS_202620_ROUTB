"""Caso de uso: actualización de los datos personales del usuario autenticado."""

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.modules.users.domain.exceptions import UserAlreadyExistsError
from app.modules.users.infrastructure.models import User
from app.modules.users.infrastructure.schemas import ProfileUpdate


def _es_telefono_duplicado(exc: IntegrityError) -> bool:
    """Reconoce la violación del índice único del teléfono.

    La comprobación previa cubre el caso normal; este respaldo traduce la
    carrera entre dos actualizaciones simultáneas al mismo número.
    """
    orig = exc.orig
    diag = getattr(orig, "diag", None)
    constraint = (
        getattr(diag, "constraint_name", None) if diag is not None else None
    )
    if constraint == "uq_users_phone":
        return True
    return "uq_users_phone" in str(orig)


def update_user_profile(
    db: Session,
    user_id: int,
    profile_data: ProfileUpdate,
) -> User:
    """Actualiza nombre, apellido y teléfono del propio usuario.

    El endpoint que invoca este caso de uso siempre toma el identificador del
    token, nunca del cuerpo: un usuario no puede editar los datos de otra
    persona.
    """
    user = db.get(User, user_id)
    if user is None:
        raise ValueError("Usuario no encontrado")

    if profile_data.phone != user.phone:
        exists = (
            db.query(User.id)
            .filter(User.phone == profile_data.phone, User.id != user_id)
            .first()
        )
        if exists is not None:
            raise UserAlreadyExistsError("El teléfono ya está registrado")

    user.name = profile_data.name
    user.last_name = profile_data.last_name
    user.phone = profile_data.phone
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        if _es_telefono_duplicado(exc):
            raise UserAlreadyExistsError("El teléfono ya está registrado") from exc
        raise
    db.refresh(user)
    return user
