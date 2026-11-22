from sqlalchemy.orm import Session

from app.modules.users.infrastructure.models import User


def select_travel_mode(db: Session, user_id: int, mode: str) -> User:
    user = db.get(User, user_id)
    if user is None:
        raise ValueError("Usuario no encontrado")
    if mode == "driver" and not user.driver_enabled:
        raise PermissionError("Registra tu vehículo para habilitar el modo conductor")
    user.preferred_mode = mode
    db.commit()
    db.refresh(user)
    return user
