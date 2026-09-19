from sqlalchemy.orm import Session

from app.modules.auth.infrastructure.security import hash_password
from app.modules.users.domain.exceptions import UserAlreadyExistsError
from app.modules.users.infrastructure.models import User
from app.modules.users.infrastructure.schemas import UserCreate


def create_user(db: Session, user_data: UserCreate) -> User:
    existing = db.query(User).filter(User.phone == user_data.phone).first()
    if existing is not None:
        raise UserAlreadyExistsError("El teléfono ya está registrado")

    db_user = User(
        name=user_data.name,
        last_name=user_data.last_name,
        phone=user_data.phone,
        hashed_password=hash_password(user_data.password),
        role=user_data.role,
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user
