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


