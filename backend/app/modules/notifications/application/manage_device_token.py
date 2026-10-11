"""Casos de uso: alta / actualización / eliminación de tokens de dispositivo."""

from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.modules.notifications.infrastructure.models import DeviceToken


def upsert_token(
    db: Session,
    user_id: int,
    device_token: str,
    platform: str,
) -> DeviceToken:
    """Inserta o actualiza el token de dispositivo para un usuario.

    Si el mismo token ya existe para ese usuario lo toca (last_seen_at).
    Si existe para otro usuario lo reasigna al actual (los dispositivos pueden
    cambiar de cuenta).
    """
    now = datetime.now(timezone.utc)

    token_row = db.scalars(
        select(DeviceToken).where(DeviceToken.device_token == device_token)
    ).first()

    if token_row is None:
        token_row = DeviceToken(
            user_id=user_id,
            device_token=device_token,
            platform=platform,
            last_seen_at=now,
        )
        db.add(token_row)
    else:
        token_row.user_id = user_id
        token_row.platform = platform
        token_row.last_seen_at = now

    db.commit()
    db.refresh(token_row)
    return token_row


def delete_token(db: Session, device_token: str, user_id: int | None) -> bool:
    """Elimina el token si pertenece al usuario. Devuelve True si se borró."""
    query = select(DeviceToken).where(DeviceToken.device_token == device_token)
    if user_id is not None:
        query = query.where(DeviceToken.user_id == user_id)
    row = db.scalars(query).first()

    if row is None:
        return False

    db.delete(row)
    db.commit()
    return True


def get_tokens_for_user(db: Session, user_id: int) -> list[DeviceToken]:
    """Devuelve todos los tokens activos registrados para un usuario."""
    return list(
        db.scalars(
            select(DeviceToken).where(DeviceToken.user_id == user_id)
        ).all()
    )
