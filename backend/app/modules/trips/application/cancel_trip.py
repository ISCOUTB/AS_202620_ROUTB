"""Cancelación consistente de viajes con notificación en cascada.

Al cancelar un viaje, todas las solicitudes activas (``pending`` o
``accepted``) pasan a ``cancelled`` en la misma transacción y los pasajeros
con solicitud aceptada reciben un aviso push después del commit.

La transición del viaje usa una actualización atómica condicionada (misma
filosofía del ADR 0003): solo la primera cancelación cambia el estado y
dispara las notificaciones; las repeticiones son idempotentes. El orden de
bloqueo (solicitudes antes que viaje) coincide con el de ``accept_request``
para evitar interbloqueos en carreras cancelar/aceptar.
"""

from sqlalchemy import select, update
from sqlalchemy.orm import Session

from app.modules.notifications.application.dispatch import PendingPush
from app.modules.requests.infrastructure.models import TripRequest
from app.modules.trips.domain.exceptions import TripNotAuthorizedError, TripNotFoundError
from app.modules.trips.infrastructure.models import Trip


def _pending_trip_cancelled(
    passenger_id: int, trip_id: int, destination: str
) -> PendingPush:
    """Aviso pendiente; el router lo programa después de la respuesta HTTP."""
    return PendingPush(
        user_id=passenger_id,
        title="Viaje cancelado",
        body=f"El conductor ha cancelado el viaje hacia {destination}.",
        data={"trip_id": str(trip_id), "event": "trip_cancelled"},
    )


def cancel_trip(
    db: Session, trip_id: int, driver_id: int | None = None
) -> tuple[Trip, list[PendingPush]]:
    trip = db.get(Trip, trip_id)
    if not trip:
        raise TripNotFoundError("Viaje no encontrado")
    if trip.driver_id is None or trip.driver_id != driver_id:
        raise TripNotAuthorizedError("No autorizado para cancelar este viaje")

    # Cargar los pasajeros a notificar antes de la actualización masiva.
    accepted_passengers = list(
        db.scalars(
            select(TripRequest.passenger_id)
            .where(
                TripRequest.trip_id == trip_id,
                TripRequest.status == "accepted",
            )
            .distinct()
        ).all()
    )

    # Cascada en la misma transacción: las filas bloqueadas por una
    # aceptación concurrente se reevalúan al hacer commit la otra transacción.
    db.execute(
        update(TripRequest)
        .where(
            TripRequest.trip_id == trip_id,
            TripRequest.status.in_(["pending", "accepted"]),
        )
        .values(status="cancelled")
        .execution_options(synchronize_session=False)
    )

    # Guardia de concurrencia: solo la primera cancelación cambia el estado.
    transitioned = db.execute(
        update(Trip)
        .where(Trip.id == trip_id, Trip.status != "cancelled")
        .values(status="cancelled")
        .execution_options(synchronize_session=False)
    )
    first_cancellation = transitioned.rowcount == 1

    db.commit()
    db.refresh(trip)

    # Los avisos se construyen después del commit y el router los programa
    # fuera del ciclo HTTP: un fallo de push no aborta la cancelación ni se
    # repite si el viaje ya estaba cancelado.
    pending: list[PendingPush] = []
    if first_cancellation:
        destination = trip.destination
        for passenger_id in accepted_passengers:
            pending.append(_pending_trip_cancelled(passenger_id, trip_id, destination))

    return trip, pending
