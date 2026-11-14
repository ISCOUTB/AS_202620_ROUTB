# Propiedad y cobertura de datos

Este documento relaciona cada entidad persistente con el módulo que es dueño
de sus datos y con la tabla PostgreSQL que la representa. El dueño es el único
módulo responsable de crear, modificar y validar la entidad; los demás módulos
deben colaborar mediante servicios o la API del backend.

## Matriz de propiedad

| Entidad | Módulo dueño | Modelo en el repositorio | Tabla PostgreSQL | Estado |
|---|---|---|---|---|
| Usuario | `users` | `backend/app/modules/users/infrastructure/models.py` | `users` | Implementada; incluye `vehicle_model`, `vehicle_plate` y `vehicle_color` opcionales (ADR 0026) |
| Recorrido (`route_geom`, `route_distance_m`, `route_duration_s`, `route_source`, `available_seats`) | `trips` | `backend/app/modules/trips/infrastructure/models.py` | `trips` | Implementada |
| Solicitud de viaje y cantidad pedida (`seat_count`) | `requests` | `backend/app/modules/requests/infrastructure/models.py` | `trip_requests` | Implementada; `seat_count` tiene valor por defecto 1 |
| Parada de solicitud (`stop_seq`, `eta_estimated`, `stop_geom`) | `requests` | `backend/app/modules/requests/infrastructure/models.py` | `request_stops` | Implementada |
| Notificación | `notifications` | `backend/app/modules/notifications/infrastructure/models.py` | `notifications` | Pendiente: verificar entidad y migración antes de declarar cobertura |
| Administración | `admin` | `backend/app/modules/admin/infrastructure/models.py` | — | Usa usuarios con rol administrativo; verificar antes de asignar entidad propia |

`auth` no posee una tabla propia: su responsabilidad es autenticar usuarios
del contexto `users` y emitir tokens JWT.

Las solicitudes (`trip_requests`), sus paradas (`request_stops`) y la cantidad
solicitada pertenecen a `requests`; el contador de disponibilidad y las métricas
y geometría de ruta del viaje pertenecen a `trips`. `requests` coordina
aceptación y liberación de cupos mediante las operaciones públicas de aplicación
`trips.application.reserve_request_seats` y
`trips.application.release_request_seats` (actualizaciones condicionales
atómicas), y delega la actualización de la ruta recalculada del viaje
(`route_geom`, `route_distance_m`, `route_duration_s`, `route_source`) a
`trips.application.set_trip_route` conservando la misma sesión y transacción
activa. Esta frontera modular está protegida por
`backend/tests/test_module_boundaries.py`.

Los datos del vehículo (`vehicle_model`, `vehicle_plate`, `vehicle_color`)
pertenecen al módulo `users` y se actualizan únicamente con
`PATCH /users/me/vehicle`. Los módulos que los consumen los reciben por la
entidad `User` ya resuelta o por `app.shared.vehicle.format_vehicle_info`, sin
duplicar la regla de visibilidad. `vehicle_info` se calcula al serializar y
solo se entrega al pasajero con solicitud `accepted`; ni `trips` ni `requests`
lo guardan (ADR 0026).

## Cobertura del código persistente

Las entidades ORM actuales se registran en `Base.metadata` y están cubiertas
por las migraciones aplicadas en Supabase:

- `User` → `users`
- `Trip` → `trips` (incluye `driver_id`, `departure_time`, `status` y campos de ruta)
- `TripRequest` → `trip_requests`
- `RequestStop` → `request_stops`

Las migraciones están en `backend/migrations/versions` y se ejecutan con:

```powershell
cd backend
alembic upgrade head
```
# Registro histórico de violaciones de propiedad de datos

> **Nota de actualización:** la tabla que sigue conserva hallazgos y rutas de
> una auditoría anterior; varias rutas ya no corresponden a la estructura
> modular actual. No es el diagnóstico vigente. Para la revisión del código y
> las correcciones comprobadas, consultar la
> [auditoría de erosión de semana 9](auditoria-erosion-semana9.md).

A continuación se detallan las violaciones arquitectónicas detectadas en el código base y el plan de acción concreto para su corrección:

| ID | Violación Detectada | Ubicación | Plan de Corrección |
|---|---|---|---|
| **V1** | **Acceso directo de auth a users:** `auth` consulta directamente la entidad `User`, propiedad de `users`. | `backend/app/modules/auth/router.py`<br>(líneas 6, 13, 23–29) | Crear en `users.service` un método `get_user_by_phone(...)` y hacer que `auth` lo consuma mediante el servicio, eliminando el import `User` y el `db.query(User)` de `auth`. |
| **V2** | **Consulta directa de User desde auth:** `auth` accede directamente a la tabla `users` mediante ORM. | `backend/app/modules/auth/service.py`<br>(líneas 12, 30, 42, 57) | Crear `users.service.get_user_by_id(...)` y utilizarlo desde `auth`. Además, desacoplar `create_access_token` de la entidad ORM `User`, usando datos primitivos o un DTO. |
| **V3** | **Fuga de entidad ORM entre módulos:** `/me` utiliza directamente la entidad `User` perteneciente a `users`. | `backend/app/modules/auth/router.py`<br>(líneas 34–41) | Definir un DTO para los datos del usuario autenticado y evitar que las entidades ORM sean transferidas entre módulos. |
| **V4** | **Acoplamiento circular users ↔ auth:** `users` depende de `auth` para `hash_password`, mientras `auth` depende de `users` para consultar usuarios. | `backend/app/modules/users/service.py`<br>(líneas 3–10)<br><br>`backend/app/modules/users/models.py`<br>(línea 11) | Mover `hash_password` y `verify_password` a `backend/app/shared/security.py`, eliminando la dependencia `users` → `auth`. |
| **V5** | **Endpoint legado de reservas en trips:** `requests` ya posee el modelo `TripRequest` y gestiona el flujo de solicitudes, pero `trips` aún conserva un endpoint independiente que descuenta cupos directamente. | `backend/app/modules/trips/router.py`<br>(líneas 61–68)<br><br>`backend/app/modules/trips/service.py`<br>(líneas 48–56) | Retirar o delegar el endpoint `/trips/{trip_id}/reservations` al módulo `requests` para que exista un único ciclo de vida de solicitudes y reservas. |
| **V6** | **Salto de capa en users:** el router accede directamente a la persistencia mediante `db.query(User)`. | `backend/app/modules/users/router.py`<br>(líneas 11–20) | Crear métodos como `get_user_by_phone(...)` y `list_users(...)` en `users.service`, y hacer que el router utilice estos servicios en lugar de consultar directamente la base de datos. |

