"""Envío de notificaciones push via Firebase Cloud Messaging (FCM).

Si FCM no está configurado (FCM_PROJECT_ID vacío) el servicio opera en modo
silencioso: registra un aviso y retorna sin error, para que los tests y el
entorno de desarrollo funcionen sin credenciales reales.
"""

import base64
import json
import logging

logger = logging.getLogger("routb.notifications")


def _get_app():
    """Inicializa la app de Firebase de forma lazy y la reutiliza."""
    import firebase_admin
    from firebase_admin import credentials

    from app.core.config import settings

    if not settings.FCM_PROJECT_ID or not settings.FCM_SERVICE_ACCOUNT_B64:
        return None

    app_name = "routb"
    existing = [a for a in firebase_admin._apps if a == app_name]  # type: ignore[attr-defined]
    if existing:
        return firebase_admin.get_app(app_name)

    try:
        sa_json = base64.b64decode(settings.FCM_SERVICE_ACCOUNT_B64).decode()
        sa_dict = json.loads(sa_json)
        cred = credentials.Certificate(sa_dict)
        return firebase_admin.initialize_app(cred, name=app_name)
    except Exception as exc:
        logger.warning("No se pudo inicializar Firebase: %s", exc)
        return None


def send_push(
    tokens: list[str],
    title: str,
    body: str,
    data: dict | None = None,
    db=None,
) -> int:
    """Envía una notificación a una lista de tokens FCM.

    Retorna el número de mensajes enviados con éxito.
    Si FCM no está configurado retorna 0 sin lanzar error.
    """
    if not tokens:
        return 0

    app = _get_app()
    if app is None:
        logger.info(
            "FCM no configurado – notificación omitida: title=%s tokens_count=%s",
            title,
            len(tokens),
        )
        return 0

    from firebase_admin import messaging

    messages = [
        messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            data=data or {},
            token=token,
        )
        for token in tokens
    ]

    batch_response = messaging.send_each(messages, app=app)
    success_count = batch_response.success_count
    if db is not None:
        from firebase_admin.messaging import UnregisteredError

        from app.modules.notifications.application.manage_device_token import delete_token

        for token, response in zip(tokens, batch_response.responses):
            if not response.success and isinstance(response.exception, UnregisteredError):
                try:
                    delete_token(db, device_token=token, user_id=None)
                except Exception:
                    logger.exception("No se pudo eliminar un token FCM inválido")
    if batch_response.failure_count:
        logger.warning(
            "FCM: %d mensajes fallidos de %d",
            batch_response.failure_count,
            len(tokens),
        )
    return success_count
