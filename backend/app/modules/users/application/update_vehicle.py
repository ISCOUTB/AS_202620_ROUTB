"""Caso de uso: registro o actualización de datos del vehículo del conductor."""

from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.modules.users.infrastructure.models import User
from app.modules.users.infrastructure.schemas import VehicleUpdate


def update_driver_vehicle(
    db: Session,
    user_id: int,
    vehicle_data: VehicleUpdate,
    *,
    activate: bool = False,
) -> User:
    """Actualiza el vehículo del conductor autenticado."""
    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        raise ValueError("Usuario no encontrado")
    if activate:
        if not all((
            vehicle_data.vehicle_model, vehicle_data.vehicle_plate, vehicle_data.vehicle_color
        )):
            raise PermissionError("Se requiere una cuenta de estudiante y un vehículo completo")
        if not user.driver_enabled:
            user.driver_activated_at = datetime.now(timezone.utc)
        user.preferred_mode = "driver"
    elif not user.driver_enabled:
        raise PermissionError("Solo los conductores pueden registrar un vehículo")

    user.vehicle_model = vehicle_data.vehicle_model
    user.vehicle_plate = vehicle_data.vehicle_plate
    user.vehicle_color = vehicle_data.vehicle_color
    db.commit()
    db.refresh(user)
    return user
