"""Despacho de notificaciones push fuera del ciclo de la petición HTTP.

Los casos de uso de ``requests`` y ``trips`` devuelven objetos
``PendingPush`` después de confirmar su transacción. Los routers los
programan con ``BackgroundTasks`` de FastAPI y la respuesta HTTP se envía sin
esperar a Firebase Cloud Messaging.

La tarea en segundo plano abre su propia sesión de SQLAlchemy porque la
sesión de la petición ya no es segura cuando la respuesta terminó. Además
absorbe cualquier error: un fallo de FCM no cambia la respuesta ni revierte
una transacción confirmada.
"""

import logging
from dataclasses import dataclass, field

from app.core.database import SessionLocal
from app.modules.notifications.application.manage_device_token import (
    get_tokens_for_user,
)
from app.modules.notifications.application.send_notification import send_push

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class PendingPush:
    """Aviso push pendiente de despachar para un usuario.

    No transporta tokens: la tarea de fondo los consulta con su propia
    sesión para no reutilizar la sesión de la petición HTTP.
    """

    user_id: int
    title: str
    body: str
    data: dict[str, str] = field(default_factory=dict)


def send_push_async_safe(pending: PendingPush) -> None:
    """Envía un aviso push sin propagar errores al ciclo de la petición.

    Se ejecuta como tarea de fondo de FastAPI, después de que la respuesta
    HTTP fue enviada. Abre y cierra su propia sesión de base de datos, incluso
    cuando FCM no está configurado o falla.
    """
    db = None
    try:
        db = SessionLocal()
        tokens = get_tokens_for_user(db, pending.user_id)
        if not tokens:
            return
        send_push(
            [token.device_token for token in tokens],
            title=pending.title,
            body=pending.body,
            data=pending.data,
            db=db,
        )
    except Exception as exc:  # noqa: BLE001 - una push nunca debe tumbar la tarea
        # Se registra el tipo, no el mensaje: una excepción de FCM podría
        # incluir el token del dispositivo.
        logger.error(
            "No se pudo despachar la notificación push event=%s error_type=%s",
            pending.data.get("event", "unknown"),
            type(exc).__name__,
        )
    finally:
        if db is not None:
            db.close()
