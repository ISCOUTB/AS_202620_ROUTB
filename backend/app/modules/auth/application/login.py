from sqlalchemy.orm import Session

from app.modules.auth.domain.exceptions import InvalidCredentialsError
from app.modules.auth.infrastructure.schemas import LoginRequest
from app.modules.auth.infrastructure.security import create_access_token, verify_password
from app.modules.users.infrastructure.models import User


def login(db: Session, credentials: LoginRequest) -> dict:
    user = db.query(User).filter(User.phone == credentials.phone).first()
    if user is None or not verify_password(credentials.password, user.hashed_password):
        raise InvalidCredentialsError("Teléfono o contraseña incorrectos")

    token = create_access_token(user)
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
