from sqlalchemy.orm import Session

from app.modules.auth.domain.exceptions import InvalidCredentialsError
from app.modules.auth.application.tokens import create_access_token
from app.modules.users.application import get_user_by_phone
from app.shared.security import verify_password


def login(db: Session, phone: str, password: str) -> dict:
    user = get_user_by_phone(db, phone)
    if user is None or not verify_password(password, user.hashed_password):
        raise InvalidCredentialsError("Teléfono o contraseña incorrectos")

    token = create_access_token(user.id, user.role)
    return {
        "access_token": token,
        "token_type": "bearer",
        "user": {
            "id": user.id,
            "name": user.name,
            "last_name": user.last_name,
            "phone": user.phone,
            "role": user.role,
        },
    }
