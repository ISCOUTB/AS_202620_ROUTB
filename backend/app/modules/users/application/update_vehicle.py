"""Caso de uso: registro o actualización de datos del vehículo del conductor."""

from sqlalchemy.orm import Session

from app.modules.users.infrastructure.models import User
from app.modules.users.infrastructure.schemas import VehicleUpdate


def update_driver_vehicle(
    db: Session,
    user_id: int,
    vehicle_data: VehicleUpdate,
) -> User:
    """Actualiza el vehículo del conductor autenticado."""
    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        raise ValueError("Usuario no encontrado")
    if user.role != "driver":
        raise PermissionError("Solo los conductores pueden registrar un vehículo")

    user.vehicle_model = vehicle_data.vehicle_model
    user.vehicle_plate = vehicle_data.vehicle_plate
    user.vehicle_color = vehicle_data.vehicle_color
    db.commit()
    db.refresh(user)
    return user
