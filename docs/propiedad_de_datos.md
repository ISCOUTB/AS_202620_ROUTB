# Propiedad y cobertura de datos

Este documento relaciona cada entidad persistente con el módulo que es dueño
de sus datos y con la tabla PostgreSQL que la representa. El dueño es el único
módulo responsable de crear, modificar y validar la entidad; los demás módulos
deben colaborar mediante servicios o la API del backend.

## Matriz de propiedad

| Entidad | Módulo dueño | Modelo en el repositorio | Tabla PostgreSQL | Estado |
|---|---|---|---|---|
| Usuario | `users` | `backend/app/modules/users/models.py:4` | `users` | Implementada |
| Recorrido | `trips` | `backend/app/modules/trips/models.py:6` | `trips` | Implementada |
| Solicitud/reserva | `requests` | `backend/app/modules/requests/models.py` | `requests` | Pendiente: no existe una entidad ORM |
| Notificación | `notifications` | `backend/app/modules/notifications/models.py` | `notifications` | Pendiente: no existe una entidad ORM |
| Administración | `admin` | `backend/app/modules/admin/models.py` | — | Pendiente: usa usuarios con rol administrativo; no tiene entidad propia |

`auth` no posee una tabla propia: su responsabilidad es autenticar usuarios
del contexto `users` y emitir tokens JWT.

## Cobertura del código persistente

Las entidades ORM actuales se registran en `Base.metadata` y están cubiertas
por la migración inicial aplicada en Supabase:

- `User` → `users`
- `Trip` → `trips`

La migración está en
`backend/migrations/versions` y se ejecuta con:

```powershell
cd backend
alembic upgrade head
```
# Registro de Violaciones de Propiedad de Datos y Acoplamiento

A continuación se detallan las violaciones arquitectónicas detectadas en el código base y el plan de acción concreto para su corrección:

| ID | Violación Detectada | Ubicación | Plan de Corrección |
|---|---|---|---|
| **V1** | **Acceso directo de auth a users:** `auth` consulta directamente la entidad `User`, propiedad de `users`. | `backend/app/modules/auth/router.py`<br>(líneas 6, 13, 23–29) | Crear en `users.service` un método `get_user_by_phone(...)` y hacer que `auth` lo consuma mediante el servicio, eliminando el import `User` y el `db.query(User)` de `auth`. |
| **V2** | **Consulta directa de User desde auth:** `auth` accede directamente a la tabla `users` mediante ORM. | `backend/app/modules/auth/service.py`<br>(líneas 12, 30, 42, 57) | Crear `users.service.get_user_by_id(...)` y utilizarlo desde `auth`. Además, desacoplar `create_access_token` de la entidad ORM `User`, usando datos primitivos o un DTO. |
| **V3** | **Fuga de entidad ORM entre módulos:** `/me` utiliza directamente la entidad `User` perteneciente a `users`. | `backend/app/modules/auth/router.py`<br>(líneas 34–41) | Definir un DTO para los datos del usuario autenticado y evitar que las entidades ORM sean transferidas entre módulos. |
| **V4** | **Acoplamiento circular users ↔ auth:** `users` depende de `auth` para `hash_password`, mientras `auth` depende de `users` para consultar usuarios. | `backend/app/modules/users/service.py`<br>(líneas 3–10)<br><br>`backend/app/modules/users/models.py`<br>(línea 11) | Mover `hash_password` y `verify_password` a `backend/app/shared/security.py`, eliminando la dependencia `users` → `auth`. |
| **V5** | **trips gestiona reservas de requests:** la reserva pertenece a `requests`, pero actualmente es gestionada desde `trips`. | `backend/app/modules/trips/router.py`<br>(líneas 23–30)<br><br>`backend/app/modules/trips/service.py`<br>(líneas 25–36) | Crear el modelo `Reservation` en `requests`, mover el endpoint de reserva a `requests` y gestionar allí su ciclo de vida. `requests` puede solicitar a `trips.service` la disminución del cupo mediante un servicio público. |
| **V6** | **Salto de capa en users:** el router accede directamente a la persistencia mediante `db.query(User)`. | `backend/app/modules/users/router.py`<br>(líneas 11–20) | Crear métodos como `get_user_by_phone(...)` y `list_users(...)` en `users.service`, y hacer que el router utilice estos servicios en lugar de consultar directamente la base de datos. |


