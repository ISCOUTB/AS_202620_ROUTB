"""Caso de uso: eliminar la cuenta del usuario autenticado.

La eliminación es física y en cascada para los datos personales:

- ``device_tokens`` y ``trip_requests`` se borran por las claves foráneas
  existentes (``ON DELETE CASCADE``).
- Los viajes históricos del conductor se conservan con ``driver_id = NULL``
  para no romper el historial de los pasajeros.

Para evitar dejar viajes o solicitudes huérfanas a medio camino, la cuenta no
se elimina mientras el usuario tenga una ruta activa como conductor o una
solicitud pendiente/aceptada como pasajero. Es una política conservadora y
fácil de explicar en la app: primero se cancelan los compromisos y luego se
borra la cuenta.
"""

from sqlalchemy.orm import Session

from app.modules.requests.infrastructure.models import TripRequest
from app.modules.trips.infrastructure.models import Trip
from app.modules.users.domain.exceptions import ActiveCommitmentsError
from app.modules.users.infrastructure.models import User


def delete_account(db: Session, user_id: int) -> None:
    """Borra la cuenta si no tiene compromisos activos."""
    user = db.get(User, user_id)
    if user is None:
        raise ValueError("Usuario no encontrado")

    has_active_trip = (
        db.query(Trip.id)
        .filter(Trip.driver_id == user_id, Trip.status == "active")
        .first()
        is not None
    )
    has_active_request = (
        db.query(TripRequest.id)
        .filter(
            TripRequest.passenger_id == user_id,
            TripRequest.status.in_(["pending", "accepted"]),
        )
        .first()
        is not None
    )
    if has_active_trip or has_active_request:
        raise ActiveCommitmentsError()

    db.delete(user)
    db.commit()
