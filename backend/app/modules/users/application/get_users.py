from dataclasses import dataclass
from datetime import datetime

from sqlalchemy.orm import Session

from app.modules.users.infrastructure.models import User


@dataclass(frozen=True)
class UserIdentity:
    id: int
    name: str
    last_name: str
    phone: str
    role: str
    location_consent_at: datetime | None


@dataclass(frozen=True)
class UserCredentials(UserIdentity):
    hashed_password: str


def get_users(db: Session) -> list[User]:
    return db.query(User).all()


def get_user_by_phone(db: Session, phone: str) -> UserCredentials | None:
    user = db.query(User).filter(User.phone == phone).first()
    if user is None:
        return None
    return UserCredentials(
        id=user.id, name=user.name, last_name=user.last_name, phone=user.phone,
        role=user.role, location_consent_at=user.location_consent_at,
        hashed_password=user.hashed_password,
    )


def get_user_by_id(db: Session, user_id: int) -> UserIdentity | None:
    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        return None
    return UserIdentity(
        id=user.id, name=user.name, last_name=user.last_name, phone=user.phone,
        role=user.role, location_consent_at=user.location_consent_at,
    )
