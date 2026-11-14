# ADR 0028: Eliminación de cuenta con bloqueo por compromisos activos

## Estado

Aceptado.

## Contexto

ROUTB no tenía una forma de que una persona eliminara su cuenta. Los datos
personales están repartidos entre `users`, `device_tokens`, `trip_requests` y
`request_stops`, mientras que los viajes publicados conservan su historial para
los pasajeros. Borrar un usuario sin más podía dejar rutas activas sin
conductor, solicitudes aceptadas sin cupo liberado o tokens push huérfanos.

La tarea G18 del sprint pedía un botón con confirmación explícita y una política
definida para los viajes activos del usuario eliminado.

## Decisión

1. **Endpoint:** `DELETE /users/me` elimina la cuenta autenticada y responde
   `204`.
2. **Bloqueo conservador:** responde `409` mientras el usuario tenga una ruta
   activa como conductor o una solicitud `pending`/`accepted` como pasajero. La
   persona debe cancelar o retirar esos compromisos primero. Así no quedan cupos
   ni viajes a medio camino.
3. **Borrado real:** sin compromisos activos se elimina la fila de `users`. Las
   claves foráneas existentes borran en cascada los tokens de dispositivo y las
   solicitudes del pasajero.
4. **Historial:** los viajes históricos del conductor se conservan con
   `driver_id = NULL` (`ON DELETE SET NULL`), de modo que los pasajeros no
   pierden su historial.
5. **Frontend:** el Perfil ofrece «Eliminar mi cuenta» con un diálogo que
   advierte que la acción es irreversible y que primero deben cancelarse los
   compromisos activos. Tras el `204` se limpia la sesión local y se vuelve al
   acceso.

## Consecuencias

- No hace falta una migración: la política usa las claves foráneas ya
  existentes.
- La cuenta no se puede recuperar; el `409` evita borrados accidentales con
  viajes en curso.
- Los viajes históricos quedan sin nombre de conductor, que es coherente con la
  eliminación de sus datos personales.
- La decisión queda registrada también en
  [`sprint/06-decisiones-pendientes.md`](../../sprint/06-decisiones-pendientes.md)
  (D6) y en `docs/evidencia/CHANGELOG-api.md`.

## Referencias

- `backend/app/modules/users/application/delete_account.py`
- `backend/app/modules/users/infrastructure/router.py`
- `backend/tests/test_user_account_deletion.py`
- `frontend/lib/features/profile/screens/profile_screen.dart`
