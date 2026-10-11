"""Caso de uso: gestión del consentimiento de ubicación del usuario."""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.timezone import colombia_now


def grant_location_consent(db: Session, user_id: int) -> None:
    """Registra la fecha y hora del consentimiento de ubicación del usuario."""
    now = colombia_now()
    db.execute(
        text("UPDATE users SET location_consent_at = :ts WHERE id = :uid").bindparams(
            ts=now, uid=user_id
        )
    )
    db.commit()


def revoke_location_consent(db: Session, user_id: int) -> None:
    """Revoca el consentimiento: anula la fecha y borra coordenadas del usuario.

    También cancela las solicitudes pendientes del usuario y elimina sus
    paradas almacenadas en ``request_stops``.
    """
    # Borrar paradas de solicitudes pendientes del usuario
    db.execute(
        text(
            """
            DELETE FROM request_stops
            WHERE request_id IN (
                SELECT id FROM trip_requests
                WHERE passenger_id = :uid AND status = 'pending'
            )
            """
        ).bindparams(uid=user_id)
    )

    # Cancelar solicitudes pendientes
    db.execute(
        text(
            "UPDATE trip_requests SET status = 'cancelled' "
            "WHERE passenger_id = :uid AND status = 'pending'"
        ).bindparams(uid=user_id)
    )

    # Revocar el consentimiento
    db.execute(
        text("UPDATE users SET location_consent_at = NULL WHERE id = :uid").bindparams(
            uid=user_id
        )
    )
    db.commit()
