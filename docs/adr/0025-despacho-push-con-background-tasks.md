# ADR 0025: Despacho de notificaciones push con `BackgroundTasks`

## Estado

Aceptado.

## Contexto

El [ADR 0022](0022-desacoplamiento-asincrono-notificaciones.md) dejó un
prototipo de mensajería asíncrona aislado (bus en memoria, idempotencia,
reintentos y DLQ), pero el flujo productivo seguía llamando a `send_push`
dentro del hilo de la petición HTTP. Una respuesta lenta de Firebase Cloud
Messaging (FCM) retenía la respuesta de `POST /requests/trips/{trip_id}`,
`PATCH /requests/{id}/accept`, `PATCH /requests/{id}/reject` y
`PATCH /trips/{id}/cancel`, aunque la transacción ya estuviera confirmada.

El bus del ADR 0022 no se incorporó a producción porque no tiene worker ni
persistencia: si el proceso se reinicia, los mensajes en memoria se pierden.
Tampoco existe todavía un broker externo en la infraestructura de Dokploy.

## Decisión

1. **`BackgroundTasks` de FastAPI como mecanismo de despacho productivo.**
   Los routers de `requests` y `trips` programan el envío con
   `background_tasks.add_task(send_push_async_safe, pending)` después de que
   el caso de uso confirmó la transacción. La respuesta HTTP no espera la
   llamada a FCM.

2. **Los casos de uso devuelven avisos pendientes, no envían push.**
   `create_request`, `accept_request`, `reject_request` y `cancel_trip`
   retornan `(resultado, list[PendingPush])`. `PendingPush` solo lleva
   `user_id`, título, cuerpo y datos; no transporta tokens ni referencias a
   objetos ORM de la sesión de la petición.

3. **La tarea de fondo es autónoma y best-effort.**
   `send_push_async_safe` abre su propia sesión con `SessionLocal`, consulta
   los tokens del usuario, llama a `send_push` y cierra la sesión en
   `finally`. Cualquier excepción se registra por tipo y se absorbe: un fallo
   de FCM no cambia la respuesta ni revierte una transacción ya confirmada.

4. **El contrato del mensaje push no cambia.** Se conservan título, cuerpo y
   `data` (`event`, `trip_id`) usados por el cliente Flutter. El envío sigue
   siendo *best-effort* y la verdad del estado sigue en PostgreSQL y la API
   REST.

## Alternativas consideradas

### Conectar el bus en memoria del ADR 0022 a los endpoints

- **Ventajas:** reutiliza el contrato, la idempotencia y la DLQ del prototipo.
- **Motivo de descarte:** no hay worker independiente ni persistencia. El
  proceso HTTP tendría que consumir la cola después de responder, con la
  misma garantía *at-most-once* ante reinicio y más complejidad operativa sin
  beneficio real para el volumen actual.

### Enviar en un hilo manual (`threading.Thread`)

- **Ventajas:** no depende de FastAPI.
- **Motivo de descarte:** un hilo por notificación sin ciclo de vida,
  límite de concurrencia ni integración con el servidor ASGI es más difícil
  de observar y apagar. `BackgroundTasks` ya usa el threadpool de Starlette
  para funciones síncronas.

### Broker externo (Kafka, RabbitMQ o Redis)

- **Ventajas:** entrega durable y desacoplamiento entre procesos.
- **Motivo de descarte:** añade un servicio, credenciales y monitoreo que no
  se justifican para el alcance y la infraestructura actuales. Queda como
  evolución posible si el volumen o la criticidad de las notificaciones
  crecen.

## Consecuencias

### Positivas

- La respuesta HTTP de crear, aceptar, rechazar y cancelar deja de esperar el
  round-trip con FCM.
- Los casos de uso quedan sin dependencia directa del adaptador FCM y son más
  fáciles de probar.
- Un fallo de FCM no se propaga al cliente ni revierte datos confirmados.

### Negativas y límites conocidos

- **Entrega *at-most-once*:** las tareas viven en el proceso. Si el
  contenedor se reinicia o cae después del commit y antes de ejecutar la
  tarea, la notificación se pierde. No hay reintentos, backoff ni DLQ en el
  flujo productivo.
- **Sin garantía de orden:** dos eventos concurrentes pueden despacharse en
  cualquier orden.
- **Consumo del threadpool:** una llamada lenta a FCM sigue ocupando un hilo
  del threadpool después de responder al cliente. No bloquea la respuesta,
  pero puede competir con otras tareas si FCM se degrada de forma sostenida.
- **Multinstancia:** cada réplica ejecuta sus propias tareas; no hay
  coordinación entre nodos. Para entrega durable se necesitaría el patrón
  *Transactional Outbox* o un broker externo.

## Verificación

- `backend/tests/test_push.py` cubre el envío al crear, aceptar y rechazar,
  que el aviso se despacha después del `commit`, que una excepción de FCM no
  revierte la respuesta y que la tarea de fondo cierra su propia sesión.
- `backend/tests/test_trips_flow.py` conserva la cobertura de cancelación en
  cascada y la carrera cancelar/aceptar.
- `backend/tests/test_notifications.py` y `backend/tests/test_requests_flow.py`
  validan el contrato REST y el registro de tokens sin cambios.

## Trazabilidad

- Despacho: `backend/app/modules/notifications/application/dispatch.py`
- Casos de uso: `backend/app/modules/requests/application/create_request.py`,
  `backend/app/modules/requests/application/manage_request.py`,
  `backend/app/modules/trips/application/cancel_trip.py`
- Routers: `backend/app/modules/requests/infrastructure/router.py`,
  `backend/app/modules/trips/infrastructure/router.py`
- Pruebas: `backend/tests/test_push.py`,
  `backend/tests/test_trips_flow.py`
- Relacionados: [ADR 0013](0013-notificaciones-push-fcm.md),
  [ADR 0022](0022-desacoplamiento-asincrono-notificaciones.md)
