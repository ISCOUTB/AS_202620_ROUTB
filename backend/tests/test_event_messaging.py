"""Pruebas automatizadas de mensajería asíncrona, desacoplamiento, idempotencia y DLQ.

Cubre los requisitos del Taller de Desacoplamiento y Mensajería:
1. Contrato del mensaje, compatibilidad aditiva y enmascaramiento de tokens.
2. Garantía de entrega 'at-least-once' a nivel de aplicación e idempotencia.
3. Fallo recuperable con reintentos y backoff exponencial (con sleep inyectable a 0 ms).
4. Agotamiento de reintentos y derivación a Dead Letter Queue (DLQ).
5. Fallo permanente no recuperable (poison pill / token revocado) derivado a DLQ.
6. Clasificación de errores FCM (503/timeout vs. UNREGISTERED).
7. Trazabilidad de logs de extremo a extremo mediante correlation_id con tokens protegidos.
8. Verificación de métricas agregadas de observabilidad.
"""

import io
import logging
from unittest.mock import MagicMock
import uuid

import pytest
from pydantic import ValidationError

from app.modules.notifications.application.event_messaging import (
    ConsumerResultStatus,
    DeadLetterQueue,
    EventConsumer,
    EventProducer,
    InMemoryIdempotencyStore,
    InMemoryMessageBus,
    MessagingMetrics,
    RetryPolicy,
    get_messaging_logger,
)
from app.modules.notifications.domain.message_contract import (
    NonRecoverableMessagingError,
    NotificationEventMessage,
    NotificationPayload,
    RecoverableMessagingError,
    is_fcm_error_recoverable,
    mask_token,
)


def _crear_mensaje(
    event_type: str = "trip_request.created",
    message_id: str | None = None,
    correlation_id: str | None = None,
    tokens: list[str] | None = None,
    extra_data: dict | None = None,
) -> NotificationEventMessage:
    """Helper para crear mensajes canónicos de prueba."""
    payload = NotificationPayload(
        user_id=42,
        tokens=tokens or ["fcm_token_privado_abcd_1234"],
        title="Nueva solicitud de viaje",
        body="Un pasajero solicitó cupo en tu viaje.",
        data=extra_data or {"trip_id": "100", "event": "request_created"},
    )
    return NotificationEventMessage(
        message_id=message_id or str(uuid.uuid4()),
        correlation_id=correlation_id or str(uuid.uuid4()),
        schema_version="1.0.0",
        event_type=event_type,
        producer="routb.backend.requests",
        payload=payload,
    )


class TestMessageContractAndCompatibility:
    """1. Pruebas de contrato, seguridad y criterio de compatibilidad."""

    def test_contrato_valido_generacion_correcta(self):
        msg = _crear_mensaje()
        assert msg.schema_version == "1.0.0"
        assert msg.event_type == "trip_request.created"
        assert msg.payload.user_id == 42
        assert len(msg.payload.tokens) == 1
        assert msg.message_id is not None
        assert msg.correlation_id is not None

    def test_enmascaramiento_de_tokens_sensibles(self):
        """Los tokens nunca deben exponerse completos en texto plano."""
        token_real = "fcm_token_super_secreto_abcd_9999"
        enmascarado = mask_token(token_real)
        assert enmascarado == "fcm_...9999"
        assert "super_secreto" not in enmascarado

        msg = _crear_mensaje(tokens=[token_real])
        safe = msg.safe_summary()
        assert safe["payload"]["tokens_masked"] == ["fcm_...9999"]
        assert "super_secreto" not in str(safe)

    def test_compatibilidad_aditiva_hacia_atras(self):
        """Campos nuevos adicionales emitidos por productores no rompen el esquema v1.0.0."""
        raw_data = {
            "message_id": "msg-compat-001",
            "correlation_id": "corr-compat-001",
            "schema_version": "1.1.0",
            "event_type": "trip_request.created",
            "producer": "routb.backend.requests",
            "timestamp": "2026-10-25T15:00:00Z",
            "campo_futuro_nuevo": "ignorado_sin_romper",
            "payload": {
                "user_id": 42,
                "tokens": ["tok_abc_123"],
                "title": "Aviso",
                "body": "Mensaje",
                "data": {"trip_id": "1"},
                "metrica_adicional": 99.9,
            },
        }

        parsed = NotificationEventMessage.model_validate(raw_data)
        assert parsed.message_id == "msg-compat-001"
        assert parsed.payload.user_id == 42

    def test_contrato_falla_si_faltan_campos_obligatorios(self):
        """Faltar campos obligatorios invalida el contrato."""
        with pytest.raises(ValidationError):
            NotificationEventMessage.model_validate({"message_id": "123"})


class TestIdempotencyAndDuplicates:
    """2 & 3. Pruebas de garantía At-Least-Once a nivel de aplicación y deduplicación."""

    def test_duplicado_es_descartado_por_idempotencia(self):
        """Un mensaje entregado dos veces solo ejecuta el despachador externo una vez."""
        dispatcher_mock = MagicMock()
        consumer = EventConsumer(
            dispatcher=dispatcher_mock,
            retry_policy=RetryPolicy(max_retries=2, backoff_base_seconds=0),
            sleep_func=lambda _: None,
        )

        mensaje = _crear_mensaje(message_id="msg-idempotente-001", correlation_id="corr-idem-001")

        # Primera entrega: procesamiento exitoso normal
        res1 = consumer.process_message(mensaje)
        assert res1.status == ConsumerResultStatus.SUCCESS
        assert res1.attempts_executed == 1
        assert dispatcher_mock.call_count == 1

        # Segunda entrega (duplicado por reintento de red del broker)
        res2 = consumer.process_message(mensaje)
        assert res2.status == ConsumerResultStatus.DUPLICATE_SKIPPED
        assert res2.attempts_executed == 0
        assert dispatcher_mock.call_count == 1
        assert consumer.metrics.duplicates_detected == 1


class TestRetryPolicyAndDLQ:
    """4 & 5. Pruebas de reintentos con backoff, inyección de sleep y DLQ."""

    def test_fallo_recuperable_con_backoff_inyectable_a_cero_ms(self):
        """Falla 2 veces con error transitorio y tiene éxito en el reintento 2 (intento 3).

        Usa sleep_func inyectable para verificar los retardos matemáticos exactos
        en 0 milisegundos de tiempo de reloj.
        """
        delays_registrados: list[float] = []
        intentos = 0

        def flaky_dispatcher(msg: NotificationEventMessage):
            nonlocal intentos
            intentos += 1
            if intentos < 3:
                raise RecoverableMessagingError(f"Corte transitorio de red FCM (intento {intentos})")
            return 1

        # max_retries = 2 -> 3 intentos en total (1 inicial + 2 reintentos)
        policy = RetryPolicy(
            max_retries=2,
            backoff_base_seconds=0.1,
            backoff_multiplier=2.0,
            enable_jitter=False,
        )

        consumer = EventConsumer(
            dispatcher=flaky_dispatcher,
            retry_policy=policy,
            sleep_func=delays_registrados.append,  # Inyección de reloj
        )

        mensaje = _crear_mensaje(correlation_id="corr-flaky-001")
        res = consumer.process_message(mensaje)

        assert res.status == ConsumerResultStatus.SUCCESS
        assert res.attempts_executed == 3
        assert intentos == 3
        assert consumer.metrics.retries_attempted == 2
        assert consumer.metrics.messages_processed_success == 1
        assert consumer.dlq.count() == 0

        # Verificación del cálculo exacto del backoff: 0.1s y 0.2s
        assert len(delays_registrados) == 2
        assert delays_registrados[0] == 0.1
        assert delays_registrados[1] == 0.2

    def test_backoff_respeta_tope_maximo_ceiling(self):
        """El backoff no debe crecer indefinidamente; se trunca en max_backoff_seconds."""
        policy = RetryPolicy(
            max_retries=10,
            backoff_base_seconds=5.0,
            backoff_multiplier=2.0,
            max_backoff_seconds=30.0,
        )
        assert policy.calculate_backoff(retry_number=1) == 5.0
        assert policy.calculate_backoff(retry_number=2) == 10.0
        assert policy.calculate_backoff(retry_number=3) == 20.0
        assert policy.calculate_backoff(retry_number=4) == 30.0  # Capped en 30s
        assert policy.calculate_backoff(retry_number=10) == 30.0  # Capped en 30s

    def test_reintentos_agotados_derivan_a_dead_letter_queue(self):
        """Fallo permanente que agota los 3 intentos debe guardarse en la DLQ con tokens enmascarados."""
        dispatcher_mock = MagicMock(side_effect=RecoverableMessagingError("FCM 503 Service Unavailable"))
        policy = RetryPolicy(max_retries=2, backoff_base_seconds=0)
        consumer = EventConsumer(
            dispatcher=dispatcher_mock,
            retry_policy=policy,
            sleep_func=lambda _: None,
        )

        mensaje = _crear_mensaje(
            message_id="msg-exhaust-001",
            correlation_id="corr-exhaust-001",
            tokens=["fcm_secreto_abcd_1234"],
        )
        res = consumer.process_message(mensaje)

        assert res.status == ConsumerResultStatus.MOVED_TO_DLQ
        assert res.attempts_executed == 3
        assert dispatcher_mock.call_count == 3
        assert consumer.metrics.dlq_messages_routed == 1
        assert consumer.dlq.count() == 1

        entry = consumer.dlq.get_all()[0]
        assert entry.message_id == "msg-exhaust-001"
        assert entry.correlation_id == "corr-exhaust-001"
        assert entry.attempt_count == 3
        assert entry.error_type == "RecoverableMessagingError"
        assert "503" in entry.error_reason
        # Seguridad: token enmascarado en la entrada de DLQ
        assert entry.safe_summary["payload"]["tokens_masked"] == ["fcm_...1234"]
        assert "secreto" not in str(entry.safe_summary)

    def test_poison_pill_va_directo_a_dlq_sin_quemar_reintentos(self):
        """Un error irrecuperable (token corrupto o revocado) pasa directo a la DLQ en intento 1."""
        dispatcher_mock = MagicMock(side_effect=NonRecoverableMessagingError("Token inválido o revocado permanentemente"))
        consumer = EventConsumer(
            dispatcher=dispatcher_mock,
            retry_policy=RetryPolicy(max_retries=2, backoff_base_seconds=0),
            sleep_func=lambda _: None,
        )

        mensaje = _crear_mensaje(message_id="msg-poison-001", correlation_id="corr-poison-001")
        res = consumer.process_message(mensaje)

        assert res.status == ConsumerResultStatus.MOVED_TO_DLQ
        assert res.attempts_executed == 1
        assert dispatcher_mock.call_count == 1
        assert consumer.metrics.retries_attempted == 0
        assert consumer.metrics.dlq_messages_routed == 1
        assert consumer.dlq.count() == 1

    def test_clasificacion_errores_fcm(self):
        """Verifica la distinción entre fallos transitorios recuperables y venenos de FCM."""
        assert is_fcm_error_recoverable(TimeoutError("Read timeout to FCM")) is True
        assert is_fcm_error_recoverable(ConnectionError("Connection reset by peer")) is True
        assert is_fcm_error_recoverable(Exception("FCM: 503 Service Unavailable")) is True

        # Venenos o tokens inválidos
        assert is_fcm_error_recoverable(Exception("Registration token is UNREGISTERED")) is False
        assert is_fcm_error_recoverable(ValueError("Malformed device token format")) is False
        assert is_fcm_error_recoverable(NonRecoverableMessagingError("Bad payload")) is False


class TestTraceabilityAndMetrics:
    """6 & 7. Pruebas de trazabilidad end-to-end con correlation_id y métricas."""

    def test_trazabilidad_log_productor_a_consumidor(self):
        """Verifica que el correlation_id se propague en los logs del productor y consumidor con tokens enmascarados."""
        msg_logger = get_messaging_logger()
        msg_logger.disabled = False
        stream = io.StringIO()
        handler = logging.StreamHandler(stream)
        handler.setLevel(logging.INFO)
        handler.setFormatter(logging.Formatter("%(message)s"))
        msg_logger.addHandler(handler)
        try:
            bus = InMemoryMessageBus()
            producer = EventProducer(bus=bus)
            dispatcher_mock = MagicMock()
            consumer = EventConsumer(
                dispatcher=dispatcher_mock,
                idempotency_store=bus.idempotency_store,
                dlq=bus.dlq,
                metrics=bus.metrics,
                bus=bus,
                sleep_func=lambda _: None,
            )

            cid_unico = f"trace-{uuid.uuid4()}"
            token_secreto = "fcm_token_privado_super_secreto_7777"
            msg = _crear_mensaje(correlation_id=cid_unico, tokens=[token_secreto])

            # 1. Productor publica
            producer.publish(msg)
            assert bus.pending_count() == 1

            # 2. Consumidor procesa
            results = bus.consume_all(consumer)
            assert len(results) == 1
            assert results[0].status == ConsumerResultStatus.SUCCESS

            # 3. Validación de logs estructurados con correlation_id y tokens enmascarados
            log_text = stream.getvalue()
            assert f"correlation_id={cid_unico}" in log_text
            assert "[PRODUCER] Publicando evento" in log_text
            assert "[CONSUMER] Recibido mensaje" in log_text
            assert "[CONSUMER] Mensaje procesado exitosamente" in log_text
            assert "fcm_...7777" in log_text
            assert "super_secreto" not in log_text  # Seguridad

            # 4. Validación de la secuencia en trace_events del bus
            assert len(bus.trace_events) >= 3
            assert bus.trace_events[0]["role"] == "PRODUCER"
            assert bus.trace_events[0]["correlation_id"] == cid_unico
            assert bus.trace_events[1]["role"] == "CONSUMER"
            assert bus.trace_events[1]["status"] == "received"
            assert bus.trace_events[1]["correlation_id"] == cid_unico
            assert bus.trace_events[2]["role"] == "CONSUMER"
            assert bus.trace_events[2]["status"] == "success"
            assert bus.trace_events[2]["correlation_id"] == cid_unico
        finally:
            msg_logger.removeHandler(handler)

    def test_metricas_globales_de_observabilidad(self):
        """Verifica el cómputo correcto de métricas operativas."""
        bus = InMemoryMessageBus()
        producer = EventProducer(bus=bus)
        dispatcher_mock = MagicMock()
        consumer = EventConsumer(
            dispatcher=dispatcher_mock,
            idempotency_store=bus.idempotency_store,
            dlq=bus.dlq,
            metrics=bus.metrics,
            sleep_func=lambda _: None,
        )

        msg1 = _crear_mensaje()
        msg2 = _crear_mensaje()

        producer.publish(msg1)
        producer.publish(msg2)
        bus.consume_all(consumer)

        snapshot = bus.metrics.snapshot()
        assert snapshot["messages_published"] == 2
        assert snapshot["messages_processed_success"] == 2
        assert snapshot["duplicates_detected"] == 0
        assert snapshot["dlq_messages_routed"] == 0
