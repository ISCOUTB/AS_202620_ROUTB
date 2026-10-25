# Concurrencia de solicitudes y cupos

Fecha: 25 de octubre de 2026.

## Alcance

Verificación de las garantías de integridad y consistencia del flujo real de
solicitudes (crear → aceptar) y de la gestión de cupos, solicitada en la
revisión de arquitectura. Complementa la prueba de reserva atómica del
[ADR 0003](../adr/0003-control-atomico-de-cupos.md)
(`backend/tests/test_cupos.py`).

## Hallazgos previos

1. `create_request` comprobaba duplicados con una lectura antes de insertar y
   no existía una restricción única en PostgreSQL: dos envíos simultáneos del
   mismo pasajero podían quedar como dos solicitudes activas.
2. Aceptar o rechazar una solicitud que otro proceso retiraba en ese instante
   podía ejecutar `db.refresh(...)` sobre una fila borrada y terminar en un
   error no controlado.
3. La prueba de concurrencia existente solo cubría `reserve_seat` (camino
   legado), no el flujo HTTP crear → aceptar ni las carreras entre acciones.

## Cambios verificados

- Migración `010_solicitud_activa_unica`: índice único parcial
  `uq_trip_requests_active_passenger` sobre `(trip_id, passenger_id)`
  `WHERE status IN ('pending', 'accepted')`.
- `create_request` traduce la violación del índice a
  `ActiveRequestAlreadyExistsError` (HTTP 400).
- `accept_request` y `reject_request` releen la solicitud cuando pierden la
  transición condicional y responden 404 si fue retirada.
- Nuevas pruebas en `backend/tests/test_requests_concurrency.py`.

## Corrida

Entorno: Windows, Python del `.venv` del backend, PostgreSQL de pruebas en un
pooler remoto de Supabase (`us-west-2`). Comando:

```bash
pytest tests/test_requests_concurrency.py -q -s
```

Resultado: **5 passed**.

| Prueba | Escenario | Resultado observado |
|---|---|---|
| `test_aceptaciones_concurrentes_respetan_los_cupos` | 8 aceptaciones simultáneas, 4 cupos | 4 aceptadas, 4 conflictos 409, `available_seats=0`, sin negativos |
| `test_creaciones_simultaneas_del_mismo_pasajero_dejan_una_activa` | 8 creaciones simultáneas del mismo pasajero y viaje | 1 creada (201), 7 rechazadas (400), 1 solicitud activa en BD |
| `test_aceptar_y_retirar_simultaneamente_no_descuadran_los_cupos` | aceptar vs retirar la misma solicitud | retiro 204, aceptación 200/404, cupos completos, sin 500 |
| `test_aceptar_y_rechazar_simultaneamente_dejan_estado_consistente` | aceptar vs rechazar | estado final `accepted` o `rejected` y cupos coherentes con ese estado |
| `test_grupo_sin_cupos_no_descuenta_parcialmente` | grupo de 2 sin cupos suficientes | 409, cupos intactos, solicitud sigue `pending` |

Nota de latencia: la corrida local reportó un p95 informativo de 15,36 s en la
primera prueba, dominado por la latencia del pooler remoto de la base de
pruebas (cada aceptación hace varias consultas). El umbral duro p95 < 3,99 s
se conserva en `test_cupos.py`, que en CI corre contra PostgreSQL local
(ADR 0003); la prueba de concurrencia verifica invariantes, no la red.

La suite completa también se ejecutó sobre el mismo entorno:

```bash
pytest -q
```

Resultado: **95 passed** en 26 min 52 s, incluida la prueba de contrato
OpenAPI y `test_cupos.py`.

## Invariantes comprobadas

- `0 <= available_seats <= total_seats` en todos los casos.
- El número de solicitudes aceptadas no supera los cupos del viaje.
- Una sola solicitud activa por `(trip_id, passenger_id)`.
- Ninguna aceptación o retiro concurrente deja cupos retenidos de más.
- Las carreras no producen respuestas 500.

## Referencias

- [ADR 0021: Integridad de solicitudes y verificación de concurrencia](../adr/0021-integridad-solicitudes-y-concurrencia.md)
- `backend/migrations/versions/010_solicitud_activa_unica.py`
- `backend/app/modules/requests/application/create_request.py`
- `backend/app/modules/requests/application/manage_request.py`
- `backend/tests/test_requests_concurrency.py`
- `backend/tests/test_cupos.py`
