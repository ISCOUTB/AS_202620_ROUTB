# ADR 0022: Desacoplamiento temporal y mensajería asíncrona para notificaciones push ante eventos de viaje

## Estado

Aceptado como **prototipo mínimo aislado y decisión registrada de no incorporarlo al sistema productivo en esta fase**.

## Contexto

En ROUTB, la asignación y aceptación de cupos se rige por una actualización atómica condicional en base de datos ([ADR 0003](0003-control-atomico-de-cupos.md)) y una comunicación síncrona REST/JSON ([ADR 0004](0004-integracion-sincrona-rest.md)). Posteriormente, el [ADR 0013](0013-notificaciones-push-fcm.md) incorporó notificaciones push mediante Firebase Cloud Messaging (FCM) como un canal de aviso no transaccional.

Sin embargo, en la implementación inicial, el despacho a FCM se ejecutaba de forma directa en el mismo hilo de la petición HTTP tras el `commit` de base de datos. Este enfoque síncrono presentaba las siguientes debilidades arquitecturales:

1. **Acoplamiento temporal y latencia innecesaria:** El conductor o pasajero que realiza una acción en la app (ej. solicitar o aceptar cupo) debe esperar a que el servidor complete el handshake TLS y la llamada de red hacia los servidores de Google FCM antes de recibir la respuesta HTTP. Si FCM experimenta congestión o latencia, la experiencia del usuario se degrada.
2. **Pérdida silenciosa de mensajes:** Ante fallos transitorios de red o códigos `503 Service Unavailable` de FCM, la implementación capturaba la excepción con un bloque pasivo (`except Exception: pass`), perdiendo la notificación de manera irrecoverable sin reintentos ni registro de fallos.
3. **Ausencia de deduplicación e idempotencia:** Si la red fallaba y el cliente móvil o un proceso automatizado reintentaba la solicitud, podían enviarse múltiples notificaciones push idénticas al usuario.
4. **Falta de observabilidad transversal y riesgo de datos sensibles:** No existía un identificador de correlación (`correlation_id`) que vinculara el evento de negocio emitido por el módulo transaccional con la entrega final o eventual fallo de la notificación, y existía el riesgo de registrar tokens FCM en texto claro.

Para evaluar este escenario sin introducir sobrecostos operativos ni romper la infraestructura ligera actual en Dokploy/Render, se construyó un **prototipo mínimo aislado** conforme a las opciones del taller de arquitectura.

---

## Decisión

Se adopta el diseño de un componente de **mensajería asíncrona desacoplada** para la emisión y entrega de notificaciones push, y se **registra la decisión de mantenerlo como un prototipo verificado sin incorporarlo al flujo productivo principal** en la versión actual.

### 1. Contrato del mensaje y criterio de compatibilidad

Se establece un contrato canónico formalizado con esquemas Pydantic (`NotificationEventMessage` y `NotificationPayload`):

* **Atributos de cabecera:**
  * `message_id`: UUID único para identificación, deduplicación e idempotencia.
  * `correlation_id`: UUID de trazabilidad distribuida extremo a extremo.
  * `schema_version`: Versión semántica del contrato (ej. `"1.0.0"`).
  * `event_type`: Tipo canónico del evento de negocio (`trip_request.created`, `trip_request.accepted`, `trip_request.rejected`).
  * `producer`: Identificador del subsistema emisor (`routb.backend.requests`).
  * `timestamp`: Fecha/hora UTC en formato ISO-8601.
* **Payload de datos y seguridad:** Contiene `user_id`, `tokens`, `title`, `body` y metadatos en `data`. Los tokens disponen de método de enmascaramiento obligatorio (`mask_token`: ej. `fcm_...1234`) para evitar fugas de datos en logs y auditorías forenses.
* **Criterio de compatibilidad:** Se adopta **compatibilidad aditiva hacia adelante (backward compatibility)** configurada con `ConfigDict(extra="ignore")`. Los consumidores v1.0 toleran campos adicionales no reconocidos emitidos por productores en versiones menores posteriores (ej. `1.1.0`), permitiendo el despliegue independiente. Cambios incompatibles (breaking changes) exigirán incremento de versión mayor (`2.0.0`).

### 2. Garantía de entrega y consecuencias asumidas

* **Garantía seleccionada:** **At-Least-Once a nivel de aplicación** (entre consumidor, broker y FCM ante fallos de red y reintentos).
* **Degradación asumida:** Debido a que el prototipo utiliza un bus en memoria, la garantía **degrada a At-Most-Once ante caída catastrófica del proceso servidor o reinicio del contenedor**, ya que los mensajes en memoria no persisten en disco.
* **Consecuencias asumidas:** Para tolerar reenvíos del emisor o del broker sin duplicar alertas en los celulares de los usuarios, **la deduplicación e idempotencia en el consumidor es obligatoria**.

### 3. Desacoplamiento temporal real

El método `EventProducer.publish(message)` es estrictamente no bloqueante: valida el contrato, asigna el `correlation_id` si no existe, encola el evento en memoria en menos de 1 ms y retorna inmediatamente el `message_id`. El hilo de la petición HTTP del usuario queda liberado de inmediato, delegando el despacho a FCM al consumidor/worker asíncrono.

### 4. Deduplicación e idempotencia

El consumidor consulta un almacén de idempotencia (`InMemoryIdempotencyStore`) indexado por `message_id`:
* Si el `message_id` ya fue procesado con éxito, el mensaje se descarta inmediatamente emitiendo un log con el `correlation_id` y retornando `DUPLICATE_SKIPPED`, evitando llamar repetidamente a la API externa de FCM y confirmando la recepción (ACK).

### 5. Política de reintentos, backoff exponencial, tope máximo y jitter

Se unifica la política de resiliencia (`RetryPolicy`):
* **Terminología formal:** 1 intento inicial + hasta 2 reintentos = **3 intentos totales permitidos**.
* **Retardo exponencial con tope y jitter:**
  $$\text{delay} = \min\left(\text{max\_backoff}, \text{base} \times (\text{multiplier}^{\text{retry\_number} - 1})\right) \pm \text{jitter}$$
  En producción: base de 0.5s, factor multiplicador 2.0, tope máximo (`max_backoff_seconds`) de 30.0s y jitter aleatorio (20%) para mitigar avalanchas.
  En pruebas: base configurable y función de espera inyectable (`sleep_func`), lo que permite validar los retardos calculados en 0 ms sin pausas de reloj reales.
* **Clasificación de errores:**
  * **Recuperables:** Timeouts, cortes de red, HTTP 503 (Servicio no disponible), HTTP 429 (Cuota excedida). Se reintentan.
  * **No recuperables (Poison Pills):** Tokens no registrados (`UNREGISTERED`), argumentos malformados o errores de serialización. Se derivan **inmediatamente a la DLQ en el intento 1** sin quemar reintentos inútiles.

### 6. Dead Letter Queue (DLQ) protegida

Almacén especializado (`DeadLetterQueue`) que preserva los mensajes que agotaron reintentos o fallaron definitivamente. Se almacena una representación segura (`safe_summary`) con **tokens FCM enmascarados**, `failed_at`, `attempt_count`, `error_type` y `error_reason` para análisis forense sin exponer credenciales.

### 7. Trazabilidad y observabilidad

Toda operación del productor y del consumidor emite logs estructurados bajo el logger `routb.messaging`, propagando el mismo `correlation_id` en cada fase del ciclo de vida (`published` $\to$ `received` $\to$ `success`/`retry`/`duplicate_skipped`/`moved_to_dlq`), con métricas acumuladas accesibles vía `bus.metrics.snapshot()`.

---

## Comparación: Prototipo Asíncrono vs. Alternativa Síncrona

| Dimensión | Solución Síncrona Actual (ADR 0004 / 0013) | Prototipo Asíncrono con Desacoplamiento (ADR 0022) |
|---|---|---|
| **Latencia HTTP para el usuario** | **Alta y variable**: La respuesta REST espera el round-trip con los servidores de Firebase (100–1200 ms). | **Mínima e invariable**: La respuesta REST retorna inmediatamente (<1 ms) tras encolar el evento en el bus local. |
| **Acoplamiento temporal** | **Fuerte**: El cliente y el servidor de Google FCM deben estar disponibles en el mismo instante. | **Débil**: El backend confirma la acción de inmediato; la notificación se entrega en segundo plano. |
| **Tolerancia a fallos de red** | **Nula**: Si Firebase está caído o da timeout, la push se descarta silenciosamente con `pass`. | **Alta**: Fallos temporales se reintentan con backoff exponencial y jitter. |
| **Manejo de mensajes venenosos** | Excepciones no controladas o descarte sin registro forense. | Se aíslan en la **Dead Letter Queue (DLQ)** protegiendo los tokens. |
| **Control de duplicados** | No existe: peticiones repetidas saturan al usuario con alertas duplicadas. | **Idempotencia garantizada**: El `message_id` impide entregas repetidas en el cliente. |
| **Consistencia de datos** | Inmediata en BD, pero aviso efímero y no confiable. | Eventual: la confirmación en pantalla es instantánea; el aviso push llega milisegundos después. |
| **Complejidad operativa** | **Mínima**: Sin estado de colas ni procesos en segundo plano. | **Moderada**: Requiere ciclo de reintentos, almacén de idempotencia y monitoreo de DLQ. |

---

## Decisión de No Incorporación al Sistema Productivo Actual

Conforme a las directrices del taller (*"Si ninguna lo justifica, construye un prototipo mínimo aislado y registra la decisión de no incorporarlo al sistema"*):

1. **Razón principal:** ROUTB opera actualmente bajo una arquitectura monolítica modular desplegada en una única instancia en Dokploy/Render. Introducir un broker distribuido pesado (Kafka o RabbitMQ) añadiría sobrecostos económicos de infraestructura, monitoreo y mantenimiento que no se justifican para el volumen de usuarios actual.
2. **Límite de la solución en memoria:** Un bus en memoria no sobrevive al reinicio del contenedor (degradación a *at-most-once* en caídas). Para llevar este patrón a producción de forma segura, el equipo esperará a la siguiente fase de escalabilidad, donde se implementará el patrón **Transactional Outbox sobre PostgreSQL**, el cual garantizará entrega durable *at-least-once* real usando las mismas tablas y transacciones de la base de datos existente sin necesidad de nuevos contenedores.
3. **Conclusión:** La solución se conserva como un prototipo probado y documentado en el módulo `notifications`, listo para activarse cuando la plataforma migre a procesamiento en worker independiente.

---

## Límites del experimento

1. **Persistencia ante reinicio del proceso:** Como el bus y el almacén de idempotencia operan en memoria, cualquier caída o reinicio del contenedor Docker descarta los mensajes pendientes (garantía *at-most-once* frente a fallos del proceso servidor).
2. **Orden de mensajes concurrentes (Sin FIFO global):** Si un conductor acepta una solicitud inmediatamente después de su creación, no se garantiza que la notificación de creación se procese antes que la de aceptación si múltiples workers atienden la cola sin particionamiento por clave (`trip_id`).
3. **Escalabilidad multi-instancia:** En un entorno con balanceador de carga y múltiples réplicas, el almacén de idempotencia local en memoria no previene duplicados procesados por diferentes nodos; requerirá una tabla en PostgreSQL o una instancia de Redis.

---

## Trazabilidad y referencias

| Elemento | Referencia |
|---|---|
| Control atómico de cupos | [ADR 0003](0003-control-atomico-de-cupos.md) |
| Integración síncrona REST | [ADR 0004](0004-integracion-sincrona-rest.md) |
| Notificaciones Push con FCM | [ADR 0013](0013-notificaciones-push-fcm.md) |
| Contrato del mensaje | `backend/app/modules/notifications/domain/message_contract.py` |
| Implementación del bus y consumidor | `backend/app/modules/notifications/application/event_messaging.py` |
| Pruebas automatizadas | `backend/tests/test_event_messaging.py` |
| Documento de entrega y evidencias | `docs/taller_mensajeria_asincrona.md` |
