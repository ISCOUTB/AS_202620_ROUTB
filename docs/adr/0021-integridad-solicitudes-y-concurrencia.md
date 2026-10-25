# ADR 0021: Integridad de solicitudes de viaje y verificación de concurrencia

## Estado

Aceptado.

## Contexto

El flujo vigente de cupos es de dos pasos: el pasajero crea una solicitud
(`POST /requests/trips/{id}`) y el conductor la acepta
(`PATCH /requests/{id}/accept`). La aceptación descuenta los cupos con una
actualización condicional atómica (`reserve_request_seats`, ADR 0003), de modo
que dos aceptaciones simultáneas nunca sobrevenden.

Sin embargo, la creación de la solicitud validaba los duplicados con una
lectura previa:

```python
existing = db.query(TripRequest).filter(...).first()
if existing:
    raise ActiveRequestAlreadyExistsError(...)
```

Entre esa lectura y la inserción no existía ninguna restricción en la base de
datos. Dos envíos simultáneos del mismo pasajero para el mismo viaje podían
pasar ambos el chequeo y quedar como dos solicitudes `pending`. La prueba de
concurrencia existente (`backend/tests/test_cupos.py`) solo cubría el camino
atómico legado `reserve_seat`, no el flujo real crear → aceptar ni las carreras
entre aceptar, retirar y rechazar.

La revisión de arquitectura pidió verificar las garantías de integridad y
consistencia de las solicitudes y de los cupos bajo peticiones simultáneas.

## Decisión

1. **Restricción única parcial en la base de datos.** La migración
   `010_solicitud_activa_unica` crea el índice único parcial
   `uq_trip_requests_active_passenger` sobre `(trip_id, passenger_id)` con la
   condición `status IN ('pending', 'accepted')`. La garantía de una sola
   solicitud activa por pasajero y viaje deja de depender de la aplicación.
   La migración concilia duplicados históricos: conserva la solicitud aceptada
   si existe (o la más antigua) y marca las demás pendientes como `cancelled`;
   las solicitudes canceladas o rechazadas no ocupan el índice, así que el
   pasajero puede volver a solicitar.

2. **Traducción del conflicto a la respuesta existente.** `create_request`
   conserva el chequeo previo como respuesta temprana y captura
   `IntegrityError`: si la violación corresponde al índice
   `uq_trip_requests_active_passenger`, lanza
   `ActiveRequestAlreadyExistsError` (HTTP 400, contrato actual); cualquier
   otra violación se propaga. No cambia el contrato OpenAPI.

3. **Transición perdida sin error 500.** Cuando el `UPDATE ... WHERE
   status = 'pending'` de aceptar o rechazar no afecta filas porque otra
   operación ganó la carrera, el caso de uso relee la solicitud con
   `db.get(...)`. Si fue retirada, responde `TripRequestNotFoundError` (404);
   si ya está en el estado esperado, responde de forma idempotente; en otro
   caso, `InvalidRequestStateError` (409). Antes, un `db.refresh(...)` sobre
   una fila borrada podía terminar en un error no controlado.

4. **Pruebas de concurrencia del flujo real.** Se agrega
   `backend/tests/test_requests_concurrency.py`, ejecutado contra PostgreSQL
   como el resto de la suite:
   - 8 aceptaciones simultáneas sobre 4 cupos: exactamente 4 aceptadas,
     4 conflictos, `available_seats = 0` y ningún valor negativo.
   - 8 creaciones simultáneas del mismo pasajero y viaje: exactamente una
     solicitud activa.
   - Aceptar y retirar la misma solicitud a la vez: cupos completos al final,
     sin doble liberación.
   - Aceptar y rechazar a la vez: estado final `accepted` o `rejected` y cupos
     coherentes con ese estado.
   - Grupo que no cabe en los cupos restantes: 409 sin descuento parcial.

5. **Sin bloqueos nuevos.** No se agregan bloqueos de fila ni niveles de
   aislamiento especiales: las transiciones y los cupos siguen resolviéndose
   con actualizaciones condicionales (ADR 0003) y el nuevo índice es
   declarativo. Se conserva el bloqueo existente sobre la fila del pasajero
   para serializar aceptaciones del mismo usuario.

## Alternativas consideradas

### Bloqueo en memoria del proceso (`threading.Lock`)

- **Ventajas:** cambio mínimo en la aplicación.
- **Motivo de descarte:** no protege varias instancias ni reinicios, y mezcla
  estado de coordinación con la lógica de negocio. La base de datos ya es el
  punto único de verdad.

### Aislamiento `SERIALIZABLE` o bloqueo de fila explícito

- **Ventajas:** elimina la carrera en la lectura.
- **Motivo de descarte:** agrega abortos y reintentos que no son necesarios
  para este invariante; además, el proyecto restringe los bloqueos de fila
  nuevos sin un ADR específico. El índice único parcial resuelve el caso con
  una sola restricción declarativa.

### Índice único sobre todos los estados

- **Ventajas:** más simple de declarar.
- **Motivo de descarte:** impediría volver a solicitar el mismo viaje después
  de una cancelación o un rechazo, que es un caso de uso válido. La condición
  parcial limita la unicidad a las solicitudes activas.

### Serializar la creación desde la aplicación

- **Ventajas:** sin cambio de esquema.
- **Motivo de descarte:** cualquier coordinación en memoria deja de funcionar
  con más de una instancia y no cubre la ventana entre lectura e inserción.
  La restricción en la base de datos vale para todos los procesos.

## Consecuencias

### Positivas

- La integridad de las solicitudes activas queda garantizada por PostgreSQL,
  no por una comprobación susceptible a carreras.
- Las carreras de aceptar/retirar/rechazar responden con códigos del contrato
  (200, 404 o 409) en lugar de un error 500.
- La suite verifica el flujo real que usa la aplicación, no solo el camino
  legado de reserva.
- Se conserva el costo $0 y el monolito modular: no hay infraestructura nueva.

### Negativas y mitigaciones

- **Costo de escritura del índice.** Es un índice parcial sobre dos columnas
  enteras; el volumen del proyecto es pequeño y la consulta de duplicados ya
  filtraba por esas columnas.
  - *Mitigación:* la condición parcial excluye los estados históricos, que son
    la mayoría con el tiempo.
- **Migración con datos existentes.** Si había duplicados pendientes, la
  migración los cancela; no toca solicitudes aceptadas.
  - *Mitigación:* la conciliación conserva la solicitud aceptada o la más
    antigua y está documentada en el encabezado de la migración.
- **La medición de latencia depende del entorno.** La base de pruebas local
  del equipo apunta a un pooler remoto de Supabase, por lo que el p95 del flujo
  completo no es comparable con el umbral de 3,99 s.
  - *Mitigación:* la prueba de concurrencia verifica invariantes y reporta el
    p95 como dato informativo; el umbral duro sigue en `test_cupos.py`, que
    corre contra PostgreSQL local en CI (ADR 0003).

## Verificación

- `pytest tests/test_requests_concurrency.py -q`: 5 pruebas en verde.
- `pytest -q`: suite completa en verde (incluye `test_cupos.py` y la prueba de
  contrato OpenAPI).
- `alembic upgrade head` aplica `010_solicitud_activa_unica` sin conflictos.
- Evidencia de la corrida: [concurrencia de solicitudes y cupos](../evidencia/concurrencia-solicitudes-cupos.md).

## Trazabilidad

| Aspecto | Referencia |
|---|---|
| Control atómico de cupos | [ADR 0003](0003-control-atomico-de-cupos.md) |
| Reserva grupal | [ADR 0007](0007-reserva-grupal-de-cupos.md) |
| Módulo de solicitudes en el monolito | [ADR 0017](0017-decision-extraccion-modulo-requests.md) |
| Código de creación | `backend/app/modules/requests/application/create_request.py` |
| Código de transiciones | `backend/app/modules/requests/application/manage_request.py` |
| Reserva y liberación atómicas | `backend/app/modules/trips/application/request_seats.py` |
| Migración | `backend/migrations/versions/010_solicitud_activa_unica.py` |
| Pruebas | `backend/tests/test_requests_concurrency.py`, `backend/tests/test_cupos.py` |
