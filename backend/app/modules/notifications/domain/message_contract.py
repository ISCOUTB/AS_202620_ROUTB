"""Contrato de mensajes de eventos de notificación para ROUTB.

Define la estructura de datos, esquema de versionado, criterios de
compatibilidad y clasificación de errores para mensajería asíncrona.
"""

from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
import uuid

from pydantic import BaseModel, ConfigDict, Field


def mask_token(token: str) -> str:
    """Enmascara un token sensible para no exponerlo en logs ni en auditorías.

    Conserva únicamente el prefijo y sufijo para trazabilidad operativa sin
    vulnerar los datos sensibles.
    """
    if not token:
        return ""
    if len(token) <= 8:
        return "***"
    return f"{token[:4]}...{token[-4:]}"


class NotificationPayload(BaseModel):
    """Payload tipado para eventos de notificación push.

    Criterio de compatibilidad:
    - Campos obligatorios mínimos: `user_id`, `title`, `body`.
    - Campos opcionales con defaults para permitir evolución aditiva sin romper
      consumidores existentes.
    """

    model_config = ConfigDict(extra="ignore")

    user_id: int = Field(..., description="ID del usuario destinatario principal")
    tokens: List[str] = Field(
        default_factory=list,
        description="Tokens de dispositivo FCM donde entregar la notificación",
    )
    title: str = Field(..., description="Título de la notificación push")
    body: str = Field(..., description="Cuerpo del mensaje de la notificación")
    data: Dict[str, str] = Field(
        default_factory=dict,
        description="Metadata clave-valor (ej. trip_id, request_id, event)",
    )

    def masked_tokens(self) -> List[str]:
        """Devuelve la lista de tokens enmascarados para observabilidad segura."""
        return [mask_token(t) for t in self.tokens]


class NotificationEventMessage(BaseModel):
    """Contrato canónico del mensaje de evento de notificación.

    Garantiza interoperabilidad, trazabilidad y compatibilidad de versiones
    entre productores (ej. módulo de solicitudes/viajes) y consumidores
    (despachador de notificaciones FCM).
    """

    model_config = ConfigDict(extra="ignore")

    message_id: str = Field(
        default_factory=lambda: str(uuid.uuid4()),
        description="Identificador único global del mensaje para deduplicación e idempotencia",
    )
    correlation_id: str = Field(
        default_factory=lambda: str(uuid.uuid4()),
        description="ID de correlación para trazabilidad distribuida extremo a extremo",
    )
    schema_version: str = Field(
        default="1.0.0",
        description="Versión semántica del esquema del contrato (ej. 1.0.0)",
    )
    event_type: str = Field(
        ...,
        description="Tipo de evento de negocio (ej. trip_request.created, trip_request.accepted)",
    )
    producer: str = Field(
        default="routb.backend.requests",
        description="Componente o módulo emisor del evento",
    )
    timestamp: datetime = Field(
        default_factory=lambda: datetime.now(timezone.utc),
        description="Marca de tiempo en UTC en que se emitió el evento",
    )
    payload: NotificationPayload = Field(
        ...,
        description="Datos específicos del evento a procesar",
    )

    def safe_summary(self) -> Dict[str, Any]:
        """Representación segura para logs y DLQ con tokens enmascarados."""
        return {
            "message_id": self.message_id,
            "correlation_id": self.correlation_id,
            "schema_version": self.schema_version,
            "event_type": self.event_type,
            "producer": self.producer,
            "timestamp": self.timestamp.isoformat(),
            "payload": {
                "user_id": self.payload.user_id,
                "tokens_masked": self.payload.masked_tokens(),
                "title": self.payload.title,
                "body": self.payload.body,
                "data": self.payload.data,
            },
        }


class RecoverableMessagingError(Exception):
    """Fallo temporal recuperable que justifica reintento con backoff (ej. timeout de red, 503, 429)."""


class NonRecoverableMessagingError(Exception):
    """Fallo permanente (veneno/poison pill, token inválido o revocado) que va directo a DLQ."""


def is_fcm_error_recoverable(exc: Exception) -> bool:
    """Clasifica si un error de FCM es transitorio o definitivo.

    - Recuperables: cortes de conexión, timeouts, HTTP 503 (Servicio no disponible),
      HTTP 429 (Cuota excedida temporalmente).
    - No recuperables (Poison Pill): tokens no registrados ('UNREGISTERED'),
      argumentos inválidos, credenciales inválidas.
    """
    exc_name = type(exc).__name__
    exc_str = str(exc).lower()

    # Errores definitivos conocidos de Firebase / FCM
    if "unregistered" in exc_str or "unregisterederror" in exc_name.lower():
        return False
    if "invalidargument" in exc_str or "invalidargumenterror" in exc_name.lower():
        return False
    if isinstance(exc, (ValueError, TypeError, KeyError)):
        return False

    # Errores temporales de red o servidor
    if isinstance(exc, (TimeoutError, ConnectionError, OSError)):
        return True
    if "503" in exc_str or "unavailable" in exc_str or "timeout" in exc_str or "deadline" in exc_str:
        return True

    # Por defecto, excepciones genéricas de mensajería respetan su tipo explícito
    if isinstance(exc, RecoverableMessagingError):
        return True
    if isinstance(exc, NonRecoverableMessagingError):
        return False

    return True
