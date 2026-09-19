from sqlalchemy.orm import Session

from app.modules.users.infrastructure.models import User


def get_users(db: Session) -> list[User]:
    return db.query(User).all()
