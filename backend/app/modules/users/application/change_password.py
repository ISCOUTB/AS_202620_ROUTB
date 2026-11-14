"""Caso de uso: cambio de contraseña con verificación de la actual."""

from sqlalchemy.orm import Session

from app.modules.users.domain.exceptions import InvalidCurrentPasswordError
from app.modules.users.infrastructure.models import User
from app.shared.security import hash_password, verify_password


def change_user_password(
    db: Session,
    user_id: int,
    current_password: str,
    new_password: str,
) -> None:
    """Cambia la contraseña después de verificar la actual.

    La verificación y el hashing reutilizan las primitivas de
    ``app.shared.security``; no se implementa criptografía propia.
    """
    user = db.get(User, user_id)
    if user is None:
        raise ValueError("Usuario no encontrado")

    if not verify_password(current_password, user.hashed_password):
        raise InvalidCurrentPasswordError()

    user.hashed_password = hash_password(new_password)
    db.commit()
