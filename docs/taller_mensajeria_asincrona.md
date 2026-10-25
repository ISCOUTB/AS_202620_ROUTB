# Taller de Arquitectura: Desacoplamiento Temporal, Mensajería y Resiliencia en ROUTB

Documento de consolidación para la entrega del taller sobre desacoplamiento temporal, reintentos y procesamiento en segundo plano en **ROUTB**.

---

## 1. Enlace al commit de entrega

* **Rama:** `Changes`
* **Commit:** [`4c906eb`](https://github.com/ISCOUTB/AS_202620_ROUTB/commit/4c906ebbadf3782972ab8b51b0c690a3c7b17947)
* **Enlace directo:** https://github.com/ISCOUTB/AS_202620_ROUTB/commit/4c906ebbadf3782972ab8b51b0c690a3c7b17947
* **Mensaje:** `feat: add asynchronous notification messaging prototype and ADR 0022`

---

## 2. Operación seleccionada y alcance del prototipo

* **Operación:** Despacho y entrega de Notificaciones Push ante eventos de Solicitudes y Viajes (`trip_request.created`, `trip_request.accepted`, `trip_request.rejected`), interactuando con el proveedor externo Firebase Cloud Messaging (FCM).
* **Naturaleza de la entrega:** Conforme a las opciones del taller (*"Si ninguna lo justifica, construye un prototipo mínimo aislado y registra la decisión de no incorporarlo al sistema"*), se implementó un **prototipo mínimo aislado** en `backend/app/modules/notifications/application/event_messaging.py` y se registró formalmente en el **[ADR 0022](adr/0022-desacoplamiento-asincrono-notificaciones.md)** la **decisión de no incorporarlo al sistema productivo principal** en la versión actual.
* **Justificación de la decisión:** ROUTB se ejecuta actualmente en una única instancia en Dokploy/Render. Añadir un broker distribuido externo (RabbitMQ o Kafka) introduce sobrecostos de mantenimiento y facturación innecesarios. Un bus en memoria degrada a *at-most-once* si el contenedor se reinicia. Para producción, el equipo adoptará el patrón **Transactional Outbox sobre PostgreSQL** cuando el tráfico lo justifique.

---

## 3. Contrato del mensaje, compatibilidad y protección de datos

El contrato canónico está formalizado con modelos Pydantic en `backend/app/modules/notifications/domain/message_contract.py`:

```python
class NotificationPayload(BaseModel):
    model_config = ConfigDict(extra="ignore")

    user_id: int
    tokens: List[str] = Field(default_factory=list)
    title: str
    body: str
    data: Dict[str, str] = Field(default_factory=dict)

    def masked_tokens(self) -> List[str]:
        return [mask_token(t) for t in self.tokens]


class NotificationEventMessage(BaseModel):
    model_config = ConfigDict(extra="ignore")

    message_id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    correlation_id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    schema_version: str = Field(default="1.0.0")
    event_type: str  # Ej: "trip_request.created", "trip_request.accepted"
    producer: str = Field(default="routb.backend.requests")
    timestamp: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    payload: NotificationPayload
```

### Criterio de compatibilidad y seguridad
* **Compatibilidad aditiva hacia adelante:** Se define `model_config = ConfigDict(extra="ignore")`. Cualquier versión menor posterior (ej. `1.1.0`) que añada campos nuevos es procesada por un consumidor v1.0.0 sin fallar.
* **Protección de datos sensibles:** Cumpliendo las políticas de seguridad del proyecto, los tokens FCM se enmascaran (`fcm_...1234`) mediante `mask_token()` tanto en los logs estructurados como en los registros forenses de la DLQ.

---

## 4. Garantía de entrega y consecuencias asumidas

* **Garantía declarada:** **At-Least-Once a nivel de aplicación** (entre consumidor, broker y FCM ante cortes transitorios de red y reintentos).
* **Degradación asumida frente a caídas del proceso:** Debido a que este prototipo utiliza un bus en memoria, la garantía **degrada a At-Most-Once frente al colapso catastrófico del proceso servidor o reinicio del contenedor**, ya que los mensajes en memoria no son persistidos en almacenamiento durable.
* **Consecuencias asumidas:** Ante reintentos por fallos de red, el consumidor asume la responsabilidad obligatoria de **deduplicación e idempotencia** antes de contactar a FCM.

---

## 5. Desacoplamiento temporal real y manejo de duplicados

* **Desacoplamiento temporal:** `EventProducer.publish(message)` es estrictamente no bloqueante: valida el mensaje, genera el `correlation_id` y lo encola en memoria en menos de 1 ms, retornando el control de inmediato. El cliente HTTP no espera la latencia de Firebase Cloud Messaging.
* **Deduplicación por idempotencia:** El consumidor consulta un almacén `InMemoryIdempotencyStore` basado en `message_id`. Si el mensaje ya fue procesado, se descarta inmediatamente emitiendo un log con el `correlation_id` y retornando `DUPLICATE_SKIPPED`, sin invocar al despachador externo:

```python
if self.idempotency_store.is_processed(mid):
    self.metrics.duplicates_detected += 1
    log.warning("[CONSUMER] Mensaje duplicado descartado por idempotencia: message_id=%s correlation_id=%s", mid, cid)
    return ConsumerResult(status=ConsumerResultStatus.DUPLICATE_SKIPPED, ...)
```

---

## 6. Política de reintentos, backoff exponencial, tope y DLQ

* **Terminología formal unificada:**
  * `max_retries = 2`: 1 intento inicial + hasta 2 reintentos = **3 intentos totales permitidos**.
* **Retardo de backoff con tope y jitter:**
  $$\text{delay} = \min\left(\text{max\_backoff}, \text{base} \times (\text{multiplier}^{\text{retry\_number} - 1})\right) \pm \text{jitter}$$
  * Producción: Base de 0.5s, factor multiplicador 2.0, tope máximo de 30.0s y jitter aleatorio (20%).
  * Pruebas: Función de espera inyectable (`sleep_func`), lo que permite verificar la exactitud de los cálculos de retardo en **0 milisegundos de tiempo de reloj**, garantizando determinismo estricto sin sleeps reales.
* **Clasificación de errores de FCM:**
  * **Recuperables:** Timeouts, cortes de red, HTTP 503 (Unavailable), HTTP 429 (Rate limit). Se reintentan.
  * **No recuperables (Poison Pills):** Tokens no registrados (`UNREGISTERED`), argumentos inválidos o payload corrupto. Se derivan **inmediatamente a la DLQ en el intento 1** sin quemar reintentos inútiles.
* **Dead Letter Queue (DLQ):** Almacén seguro (`DeadLetterQueue`) que custodia los mensajes no entregables, preservando su `correlation_id`, `failed_at`, `attempt_count`, `error_type`, `error_reason` y un `safe_summary` con **tokens enmascarados**.

---

## 7. Trazabilidad con logs reales de ejecución y métricas

### Traza real 1: Despacho exitoso de extremo a extremo (Productor a Consumidor)
*(Captura real de ejecución con `pytest tests/test_event_messaging.py -k "test_trazabilidad" -s`)*:

```text
INFO  [routb.messaging] [PRODUCER] Publicando evento: event_type=trip_request.created message_id=3d5f4591-9d0e-4fd0-a932-5646c9e0f80b correlation_id=trace-5c11cacc-caaa-4d7c-8194-c151eff2ada0 producer=routb.backend.requests tokens_masked=['fcm_...7777']
INFO  [routb.messaging] [CONSUMER] Recibido mensaje event_type=trip_request.created message_id=3d5f4591-9d0e-4fd0-a932-5646c9e0f80b correlation_id=trace-5c11cacc-caaa-4d7c-8194-c151eff2ada0 schema_version=1.0.0 tokens_masked=['fcm_...7777']
INFO  [routb.messaging] [CONSUMER] Procesando intento 1/3 (inicial): message_id=3d5f4591-9d0e-4fd0-a932-5646c9e0f80b correlation_id=trace-5c11cacc-caaa-4d7c-8194-c151eff2ada0
INFO  [routb.messaging] [CONSUMER] Mensaje procesado exitosamente: message_id=3d5f4591-9d0e-4fd0-a932-5646c9e0f80b correlation_id=trace-5c11cacc-caaa-4d7c-8194-c151eff2ada0 en intento 1/3 (inicial)
```

### Traza real 2: Fallo recuperable con reintentos y backoff
*(Captura real con `pytest tests/test_event_messaging.py -k "test_fallo_recuperable" -s`)*:

```text
INFO  [routb.messaging] [CONSUMER] Recibido mensaje event_type=trip_request.created message_id=f704922f-bd75-4e24-acc7-f41feebaeccf correlation_id=corr-flaky-001 schema_version=1.0.0 tokens_masked=['fcm_...1234']
INFO  [routb.messaging] [CONSUMER] Procesando intento 1/3 (inicial): message_id=f704922f-bd75-4e24-acc7-f41feebaeccf correlation_id=corr-flaky-001
WARNI [routb.messaging] [CONSUMER] Fallo recuperable en intento 1/3 (inicial): message_id=f704922f-bd75-4e24-acc7-f41feebaeccf correlation_id=corr-flaky-001 error=Corte transitorio de red FCM (intento 1). Reintentando tras backoff de 0.100s.
INFO  [routb.messaging] [CONSUMER] Procesando intento 2/3 (reintento 1/2): message_id=f704922f-bd75-4e24-acc7-f41feebaeccf correlation_id=corr-flaky-001
WARNI [routb.messaging] [CONSUMER] Fallo recuperable en intento 2/3 (reintento 1/2): message_id=f704922f-bd75-4e24-acc7-f41feebaeccf correlation_id=corr-flaky-001 error=Corte transitorio de red FCM (intento 2). Reintentando tras backoff de 0.200s.
INFO  [routb.messaging] [CONSUMER] Procesando intento 3/3 (reintento 2/2): message_id=f704922f-bd75-4e24-acc7-f41feebaeccf correlation_id=corr-flaky-001
INFO  [routb.messaging] [CONSUMER] Mensaje procesado exitosamente: message_id=f704922f-bd75-4e24-acc7-f41feebaeccf correlation_id=corr-flaky-001 en intento 3/3 (reintento 2/2)
```

### Traza real 3: Reintentos agotados y derivación a Dead Letter Queue (DLQ)
*(Captura real con `pytest tests/test_event_messaging.py -k "test_reintentos_agotados" -s`)*:

```text
INFO  [routb.messaging] [CONSUMER] Recibido mensaje event_type=trip_request.created message_id=msg-exhaust-001 correlation_id=corr-exhaust-001 schema_version=1.0.0 tokens_masked=['fcm_...1234']
INFO  [routb.messaging] [CONSUMER] Procesando intento 1/3 (inicial): message_id=msg-exhaust-001 correlation_id=corr-exhaust-001
WARNI [routb.messaging] [CONSUMER] Fallo recuperable en intento 1/3 (inicial): message_id=msg-exhaust-001 correlation_id=corr-exhaust-001 error=FCM 503 Service Unavailable. Reintentando tras backoff de 0.000s.
INFO  [routb.messaging] [CONSUMER] Procesando intento 2/3 (reintento 1/2): message_id=msg-exhaust-001 correlation_id=corr-exhaust-001
WARNI [routb.messaging] [CONSUMER] Fallo recuperable en intento 2/3 (reintento 1/2): message_id=msg-exhaust-001 correlation_id=corr-exhaust-001 error=FCM 503 Service Unavailable. Reintentando tras backoff de 0.000s.
INFO  [routb.messaging] [CONSUMER] Procesando intento 3/3 (reintento 2/2): message_id=msg-exhaust-001 correlation_id=corr-exhaust-001
ERROR [routb.messaging] [CONSUMER] Reintentos agotados (3/3): message_id=msg-exhaust-001 correlation_id=corr-exhaust-001 error=FCM 503 Service Unavailable. Despachando a DLQ.
```

### Métricas operativas expuestas
El objeto `bus.metrics.snapshot()` expone el estado acumulado para observabilidad:
```json
{
  "messages_published": 2,
  "messages_processed_success": 2,
  "duplicates_detected": 0,
  "retries_attempted": 0,
  "dlq_messages_routed": 0
}
```

---

## 8. Pruebas automatizadas y evidencia de ejecución

Ubicación de la suite: `backend/tests/test_event_messaging.py`.

### 12 Pruebas implementadas
1. `test_contrato_valido_generacion_correcta`: Valida estructura y tipos del contrato canónico.
2. `test_enmascaramiento_de_tokens_sensibles`: Valida enmascaramiento seguro de credenciales.
3. `test_compatibilidad_aditiva_hacia_atras`: Valida tolerancia a campos nuevos adicionales sin romper.
4. `test_contrato_falla_si_faltan_campos_obligatorios`: Valida rechazo estricto ante payload incompleto.
5. `test_duplicado_es_descartado_por_idempotencia`: **Demuestra descarte de duplicado con 1 sola ejecución real**.
6. `test_fallo_recuperable_con_backoff_inyectable_a_cero_ms`: **Demuestra recuperación tras 2 reintentos con cálculo exacto de backoff**.
7. `test_backoff_respeta_tope_maximo_ceiling`: Valida que el retardo se trunca en el tope máximo configurado.
8. `test_reintentos_agotados_derivan_a_dead_letter_queue`: **Demuestra derivación a DLQ con tokens enmascarados**.
9. `test_poison_pill_va_directo_a_dlq_sin_quemar_reintentos`: Demuestra aislamiento inmediato en intento 1.
10. `test_clasificacion_errores_fcm`: Demuestra discriminación de errores transitorios frente a venenos.
11. `test_trazabilidad_log_productor_a_consumidor`: **Demuestra propagación de correlation_id y enmascaramiento**.
12. `test_metricas_globales_de_observabilidad`: Demuestra cómputo exacto de métricas acumuladas.

### Ejecución completa de la suite
```bash
.\.venv\Scripts\pytest tests/test_event_messaging.py -v
```

```text
============================= test session starts =============================
platform win32 -- Python 3.14.4, pytest-9.0.1, pluggy-1.6.0
rootdir: C:\vd_code\AS_202620_ROUTB\backend
collected 12 items

tests/test_event_messaging.py::TestMessageContractAndCompatibility::test_contrato_valido_generacion_correcta PASSED [  8%]
tests/test_event_messaging.py::TestMessageContractAndCompatibility::test_enmascaramiento_de_tokens_sensibles PASSED [ 16%]
tests/test_event_messaging.py::TestMessageContractAndCompatibility::test_compatibilidad_aditiva_hacia_atras PASSED [ 25%]
tests/test_event_messaging.py::TestMessageContractAndCompatibility::test_contrato_falla_si_faltan_campos_obligatorios PASSED [ 33%]
tests/test_event_messaging.py::TestIdempotencyAndDuplicates::test_duplicado_es_descartado_por_idempotencia PASSED [ 41%]
tests/test_event_messaging.py::TestRetryPolicyAndDLQ::test_fallo_recuperable_con_backoff_inyectable_a_cero_ms PASSED [ 50%]
tests/test_event_messaging.py::TestRetryPolicyAndDLQ::test_backoff_respeta_tope_maximo_ceiling PASSED [ 58%]
tests/test_event_messaging.py::TestRetryPolicyAndDLQ::test_reintentos_agotados_derivan_a_dead_letter_queue PASSED [ 66%]
tests/test_event_messaging.py::TestRetryPolicyAndDLQ::test_poison_pill_va_directo_a_dlq_sin_quemar_reintentos PASSED [ 75%]
tests/test_event_messaging.py::TestRetryPolicyAndDLQ::test_clasificacion_errores_fcm PASSED [ 83%]
tests/test_event_messaging.py::TestTraceabilityAndMetrics::test_trazabilidad_log_productor_a_consumidor PASSED [ 91%]
tests/test_event_messaging.py::TestTraceabilityAndMetrics::test_metricas_globales_de_observabilidad PASSED [100%]

======================= 12 passed, 2 warnings in 27.23s =======================
```

> **Nota sobre el tiempo de ejecución y warnings:**
> * Las 12 pruebas de mensajería se ejecutan en **< 0.05 segundos** gracias a la inyección de `sleep_func`. El tiempo de 27s se debe exclusivamente al fixture de sesión en `conftest.py` que ejecuta `alembic upgrade head` (10 migraciones sobre PostgreSQL) antes de la suite y `downgrade base` al finalizar.
> * Las 2 advertencias provienen de bibliotecas externas del proyecto (`alembic.config` deprecation de `prepend_sys_path` y Starlette `BlockingPortal`), ajenas al módulo implementado.

---

## 9. Arquitectura y ADR de decisión

La evaluación detallada de la arquitectura, la comparación con la alternativa síncrona y la decisión de mantenerlo como prototipo aislado se encuentran formalizadas en el **[ADR 0022](adr/0022-desacoplamiento-asincrono-notificaciones.md)**.

---

## 10. Límites del experimento

1. **Persistencia ante caída del proceso:** Al operar el bus y el almacén de idempotencia en memoria, cualquier reinicio del contenedor o fallo del proceso servidor borra los mensajes pendientes. La garantía real frente al colapso del proceso es *at-most-once*. En producción, se requerirá almacenamiento durable (Transactional Outbox o broker externo).
2. **Ausencia de garantía de orden global (FIFO):** Si dos eventos sobre el mismo viaje ocurren en rápida sucesión (`trip_request.created` y `trip_request.accepted`), no existe garantía de orden estricto si son consumidos en paralelo sin particionado por clave (`trip_id`).
3. **Escalabilidad horizontal:** El almacén de idempotencia en memoria no previene duplicados procesados por diferentes réplicas de servidor bajo un balanceador de carga; requeriría una base de datos centralizada (PostgreSQL o Redis).
