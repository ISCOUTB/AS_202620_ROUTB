from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.shared.security import hash_password
from app.modules.users.domain.exceptions import UserAlreadyExistsError
from app.modules.users.infrastructure.models import User
from app.modules.users.infrastructure.schemas import UserCreate


def _es_telefono_duplicado(exc: IntegrityError) -> bool:
    orig = exc.orig
    diag = getattr(orig, "diag", None)
    constraint = getattr(diag, "constraint_name", None) if diag is not None else None
    if constraint == "uq_users_phone":
        return True
    return "uq_users_phone" in str(orig)


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
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        if _es_telefono_duplicado(exc):
            raise UserAlreadyExistsError("El teléfono ya está registrado") from exc
        raise
    db.refresh(db_user)
    return db_user
