"""Módulo de mensajería desacoplada para notificaciones en ROUTB.

Implementa los componentes del patrón productor-consumidor asíncrono:
- Bus de mensajes en memoria (prototipo mínimo aislado).
- Almacén de idempotencia y deduplicación por message_id.
- Política de reintentos con backoff exponencial, tope máximo y jitter configurable.
- Función de espera (sleep_func) inyectable para pruebas deterministas en 0 ms.
- Enmascaramiento de tokens sensibles en logs y en la Dead Letter Queue (DLQ).
- Clasificación de errores FCM (recuperables vs. no recuperables).
- Trazabilidad distribuida con correlation_id estructurado.
- Métricas de observabilidad de mensajería.
"""

from collections import deque
from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
import logging
import random
import time
from typing import Any, Callable, Dict, List, Optional, Set

from app.modules.notifications.domain.message_contract import (
    NonRecoverableMessagingError,
    NotificationEventMessage,
    RecoverableMessagingError,
    is_fcm_error_recoverable,
    mask_token,
)


def get_messaging_logger() -> logging.Logger:
    """Devuelve el logger de mensajería asegurando que no quede deshabilitado por alembic fileConfig."""
    log = logging.getLogger("routb.messaging")
    log.setLevel(logging.INFO)
    log.disabled = False
    return log


logger = get_messaging_logger()


class ConsumerResultStatus(str, Enum):
    SUCCESS = "success"
    DUPLICATE_SKIPPED = "duplicate_skipped"
    MOVED_TO_DLQ = "moved_to_dlq"


@dataclass
class ConsumerResult:
    """Resultado del procesamiento de un mensaje por el consumidor."""

    status: ConsumerResultStatus
    message_id: str
    correlation_id: str
    attempts_executed: int
    detail: Optional[str] = None


@dataclass
class DeadLetterEntry:
    """Registro de mensaje archivado en la Dead Letter Queue (DLQ).

    Los tokens sensibles se preservan enmascarados para evitar fugas de datos
    en registros de auditoría forense.
    """

    message_id: str
    correlation_id: str
    event_type: str
    failed_at: datetime
    attempt_count: int
    error_type: str
    error_reason: str
    safe_summary: Dict[str, Any]
    original_message: NotificationEventMessage


class DeadLetterQueue:
    """Cola de mensajes muertos (DLQ).

    Almacena mensajes que fallaron definitivamente para auditoría, inspección
    forense y posible re-encolado manual, protegiendo datos sensibles.
    """

    def __init__(self) -> None:
        self._entries: List[DeadLetterEntry] = []

    def enqueue(self, entry: DeadLetterEntry) -> None:
        self._entries.append(entry)

    def get_all(self) -> List[DeadLetterEntry]:
        return list(self._entries)

    def count(self) -> int:
        return len(self._entries)

    def clear(self) -> None:
        self._entries.clear()


class InMemoryIdempotencyStore:
    """Almacén de idempotencia en memoria basado en message_id.

    Garantiza que un mensaje entregado bajo la semántica 'at-least-once' no
    sea procesado más de una vez por el consumidor.
    """

    def __init__(self) -> None:
        self._processed_ids: Set[str] = set()

    def is_processed(self, message_id: str) -> bool:
        return message_id in self._processed_ids

    def mark_processed(self, message_id: str) -> None:
        self._processed_ids.add(message_id)

    def clear(self) -> None:
        self._processed_ids.clear()


@dataclass
class RetryPolicy:
    """Política de reintentos con backoff exponencial, tope máximo y jitter.

    Terminología unificada:
    - max_retries: Cantidad de reintentos tras el intento inicial.
      Ej: max_retries=2 implica un total de 3 intentos (1 inicial + 2 reintentos).
    - backoff_base_seconds: Base del retardo en segundos (ej. 0.5s en prod; 0.05s en tests).
    - backoff_multiplier: Factor multiplicador exponencial (ej. 2.0).
    - max_backoff_seconds: Tope máximo de espera (ceiling, ej. 30.0s).
    - enable_jitter: Añade variación aleatoria para mitigar el efecto de manada.
    """

    max_retries: int = 2
    backoff_base_seconds: float = 0.5
    backoff_multiplier: float = 2.0
    max_backoff_seconds: float = 30.0
    enable_jitter: bool = False
    jitter_factor: float = 0.2

    @property
    def total_allowed_attempts(self) -> int:
        """Total de intentos permitidos (intento inicial + reintentos)."""
        return 1 + self.max_retries

    def calculate_backoff(self, retry_number: int) -> float:
        """Calcula el retardo para el reintento `retry_number` (1, 2, ...).

        Fórmula: min(max_backoff, base * (multiplier ** (retry_number - 1)))
        """
        if self.backoff_base_seconds <= 0:
            return 0.0

        calculated = self.backoff_base_seconds * (
            self.backoff_multiplier ** (retry_number - 1)
        )
        delay = min(self.max_backoff_seconds, calculated)

        if self.enable_jitter and delay > 0:
            variation = delay * self.jitter_factor
            delay += random.uniform(-variation, variation)

        return max(0.0, round(delay, 4))


@dataclass
class MessagingMetrics:
    """Métricas operativas del bus y consumidor de mensajería."""

    messages_published: int = 0
    messages_processed_success: int = 0
    duplicates_detected: int = 0
    retries_attempted: int = 0
    dlq_messages_routed: int = 0

    def snapshot(self) -> Dict[str, int]:
        """Devuelve un volcado de las métricas acumuladas para inspección."""
        return {
            "messages_published": self.messages_published,
            "messages_processed_success": self.messages_processed_success,
            "duplicates_detected": self.duplicates_detected,
            "retries_attempted": self.retries_attempted,
            "dlq_messages_routed": self.dlq_messages_routed,
        }

    def reset(self) -> None:
        self.messages_published = 0
        self.messages_processed_success = 0
        self.duplicates_detected = 0
        self.retries_attempted = 0
        self.dlq_messages_routed = 0


class EventConsumer:
    """Consumidor desacoplado de eventos de notificación.

    Aplica:
    1. Trazabilidad con correlation_id en cada log estructurado.
    2. Deduplicación e idempotencia mediante message_id.
    3. Reintentos con backoff exponencial ante fallos transitorios.
    4. Inyección de sleep_func para pruebas sin retardo artificial (0 ms).
    5. Derivación inmediata o tras agotar intentos hacia la DLQ con datos enmascarados.
    """

    def __init__(
        self,
        dispatcher: Callable[[NotificationEventMessage], Any],
        idempotency_store: Optional[InMemoryIdempotencyStore] = None,
        retry_policy: Optional[RetryPolicy] = None,
        dlq: Optional[DeadLetterQueue] = None,
        metrics: Optional[MessagingMetrics] = None,
        sleep_func: Callable[[float], None] = time.sleep,
        bus: Optional["InMemoryMessageBus"] = None,
    ) -> None:
        self.dispatcher = dispatcher
        self.idempotency_store = idempotency_store or InMemoryIdempotencyStore()
        self.retry_policy = retry_policy or RetryPolicy()
        self.dlq = dlq or DeadLetterQueue()
        self.metrics = metrics or MessagingMetrics()
        self.sleep_func = sleep_func
        self.bus = bus
        self.audit_log: List[Dict[str, Any]] = []

    def _record_audit(
        self,
        role: str,
        status: str,
        message: NotificationEventMessage,
        attempt: int = 1,
        detail: str = "",
    ) -> None:
        entry = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "role": role,
            "status": status,
            "message_id": message.message_id,
            "correlation_id": message.correlation_id,
            "event_type": message.event_type,
            "attempt": attempt,
            "tokens_masked": message.payload.masked_tokens(),
            "detail": detail,
        }
        self.audit_log.append(entry)
        if self.bus is not None:
            self.bus.trace_events.append(entry)

    def process_message(self, message: NotificationEventMessage) -> ConsumerResult:
        log = get_messaging_logger()
        cid = message.correlation_id
        mid = message.message_id
        etype = message.event_type
        total_attempts = self.retry_policy.total_allowed_attempts
        tokens_masked = message.payload.masked_tokens()

        log.info(
            "[CONSUMER] Recibido mensaje event_type=%s message_id=%s correlation_id=%s schema_version=%s tokens_masked=%s",
            etype,
            mid,
            cid,
            message.schema_version,
            tokens_masked,
        )
        self._record_audit(role="CONSUMER", status="received", message=message)

        # 1. Chequeo de deduplicación / idempotencia
        if self.idempotency_store.is_processed(mid):
            self.metrics.duplicates_detected += 1
            log.warning(
                "[CONSUMER] Mensaje duplicado descartado por idempotencia: message_id=%s correlation_id=%s",
                mid,
                cid,
            )
            self._record_audit(
                role="CONSUMER",
                status="duplicate_skipped",
                message=message,
                attempt=0,
                detail="Mensaje duplicado descartado; ya había sido procesado exitosamente.",
            )
            return ConsumerResult(
                status=ConsumerResultStatus.DUPLICATE_SKIPPED,
                message_id=mid,
                correlation_id=cid,
                attempts_executed=0,
                detail="Mensaje duplicado descartado; ya había sido procesado exitosamente.",
            )

        # 2. Ciclo de intentos (1 inicial + max_retries reintentos)
        last_exception: Optional[Exception] = None
        for attempt_index in range(1, total_attempts + 1):
            is_initial = attempt_index == 1
            retry_count = attempt_index - 1
            attempt_label = (
                f"intento {attempt_index}/{total_attempts} (inicial)"
                if is_initial
                else f"intento {attempt_index}/{total_attempts} (reintento {retry_count}/{self.retry_policy.max_retries})"
            )

            try:
                log.info(
                    "[CONSUMER] Procesando %s: message_id=%s correlation_id=%s",
                    attempt_label,
                    mid,
                    cid,
                )
                self.dispatcher(message)

                # Éxito: marcamos idempotencia y actualizamos métricas
                self.idempotency_store.mark_processed(mid)
                self.metrics.messages_processed_success += 1
                log.info(
                    "[CONSUMER] Mensaje procesado exitosamente: message_id=%s correlation_id=%s en %s",
                    mid,
                    cid,
                    attempt_label,
                )
                self._record_audit(
                    role="CONSUMER",
                    status="success",
                    message=message,
                    attempt=attempt_index,
                    detail=f"Exito en {attempt_label}",
                )
                return ConsumerResult(
                    status=ConsumerResultStatus.SUCCESS,
                    message_id=mid,
                    correlation_id=cid,
                    attempts_executed=attempt_index,
                )

            except Exception as exc:
                last_exception = exc
                recoverable = is_fcm_error_recoverable(exc)

                if not recoverable:
                    # Fallo permanente (veneno / token revocado): directo a DLQ
                    log.error(
                        "[CONSUMER] Fallo permanente no recuperable (poison pill): message_id=%s correlation_id=%s error=%s. Enviando directo a DLQ sin quemar reintentos.",
                        mid,
                        cid,
                        exc,
                    )
                    entry = DeadLetterEntry(
                        message_id=mid,
                        correlation_id=cid,
                        event_type=etype,
                        failed_at=datetime.now(timezone.utc),
                        attempt_count=attempt_index,
                        error_type=type(exc).__name__,
                        error_reason=str(exc),
                        safe_summary=message.safe_summary(),
                        original_message=message,
                    )
                    self.dlq.enqueue(entry)
                    self.metrics.dlq_messages_routed += 1
                    self._record_audit(
                        role="CONSUMER",
                        status="moved_to_dlq",
                        message=message,
                        attempt=attempt_index,
                        detail=f"Fallo permanente no recuperable: {exc}",
                    )
                    return ConsumerResult(
                        status=ConsumerResultStatus.MOVED_TO_DLQ,
                        message_id=mid,
                        correlation_id=cid,
                        attempts_executed=attempt_index,
                        detail=f"Fallo permanente no recuperable: {exc}",
                    )

                # Error recuperable: evaluar si quedan reintentos
                if attempt_index < total_attempts:
                    self.metrics.retries_attempted += 1
                    delay = self.retry_policy.calculate_backoff(retry_number=attempt_index)
                    log.warning(
                        "[CONSUMER] Fallo recuperable en %s: message_id=%s correlation_id=%s error=%s. Reintentando tras backoff de %.3fs.",
                        attempt_label,
                        mid,
                        cid,
                        exc,
                        delay,
                    )
                    self._record_audit(
                        role="CONSUMER",
                        status="retry_scheduled",
                        message=message,
                        attempt=attempt_index,
                        detail=f"Delay: {delay:.3f}s. Error: {exc}",
                    )
                    if delay > 0:
                        self.sleep_func(delay)
                else:
                    log.error(
                        "[CONSUMER] Reintentos agotados (%d/%d): message_id=%s correlation_id=%s error=%s. Despachando a DLQ.",
                        attempt_index,
                        total_attempts,
                        mid,
                        cid,
                        exc,
                    )

        # 3. Derivación a DLQ por agotamiento de reintentos
        entry = DeadLetterEntry(
            message_id=mid,
            correlation_id=cid,
            event_type=etype,
            failed_at=datetime.now(timezone.utc),
            attempt_count=total_attempts,
            error_type=type(last_exception).__name__ if last_exception else "UnknownError",
            error_reason=str(last_exception) if last_exception else "Reintentos agotados",
            safe_summary=message.safe_summary(),
            original_message=message,
        )
        self.dlq.enqueue(entry)
        self.metrics.dlq_messages_routed += 1
        self._record_audit(
            role="CONSUMER",
            status="moved_to_dlq",
            message=message,
            attempt=total_attempts,
            detail=f"Reintentos agotados tras {total_attempts} intentos: {last_exception}",
        )
        return ConsumerResult(
            status=ConsumerResultStatus.MOVED_TO_DLQ,
            message_id=mid,
            correlation_id=cid,
            attempts_executed=total_attempts,
            detail=f"Reintentos agotados tras {total_attempts} intentos: {last_exception}",
        )


class EventProducer:
    """Productor de eventos de notificación.

    Construye y emite eventos hacia el bus con trazabilidad unificada.
    La publicación es estrictamente no bloqueante: valida el contrato,
    asigna identificadores y encola en memoria en menos de 1 ms.
    """

    def __init__(
        self,
        bus: "InMemoryMessageBus",
        metrics: Optional[MessagingMetrics] = None,
        producer_id: str = "routb.backend.requests",
    ) -> None:
        self.bus = bus
        self.metrics = metrics or bus.metrics
        self.producer_id = producer_id

    def publish(self, message: NotificationEventMessage) -> str:
        log = get_messaging_logger()
        log.info(
            "[PRODUCER] Publicando evento: event_type=%s message_id=%s correlation_id=%s producer=%s tokens_masked=%s",
            message.event_type,
            message.message_id,
            message.correlation_id,
            self.producer_id,
            message.payload.masked_tokens(),
        )
        self.metrics.messages_published += 1
        entry = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "role": "PRODUCER",
            "status": "published",
            "message_id": message.message_id,
            "correlation_id": message.correlation_id,
            "event_type": message.event_type,
            "producer": self.producer_id,
            "tokens_masked": message.payload.masked_tokens(),
        }
        self.bus.trace_events.append(entry)
        self.bus.enqueue(message)
        return message.message_id


class InMemoryMessageBus:
    """Simulador local de bus de mensajería desacoplado (prototipo mínimo aislado).

    Implementa una cola de mensajes en memoria con semántica 'at-least-once' a
    nivel de consumidor/red, permitiendo pruebas exhaustivas, deterministas y
    sin dependencias de infraestructura externa.
    """

    def __init__(self) -> None:
        self._queue: deque[NotificationEventMessage] = deque()
        self.metrics = MessagingMetrics()
        self.idempotency_store = InMemoryIdempotencyStore()
        self.dlq = DeadLetterQueue()
        self.trace_events: List[Dict[str, Any]] = []

    def enqueue(self, message: NotificationEventMessage) -> None:
        self._queue.append(message)

    def pending_count(self) -> int:
        return len(self._queue)

    def consume_next(self, consumer: EventConsumer) -> Optional[ConsumerResult]:
        if not self._queue:
            return None
        message = self._queue.popleft()
        return consumer.process_message(message)

    def consume_all(self, consumer: EventConsumer) -> List[ConsumerResult]:
        results: List[ConsumerResult] = []
        while self._queue:
            message = self._queue.popleft()
            results.append(consumer.process_message(message))
        return results

    def clear(self) -> None:
        self._queue.clear()
        self.metrics.reset()
        self.idempotency_store.clear()
        self.dlq.clear()
        self.trace_events.clear()
