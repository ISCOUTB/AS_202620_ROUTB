# Auditoría de erosión modular — Semana 9

## Alcance y método

Se contrastaron los registros históricos de propiedad de datos con el código
actual usando búsquedas de imports entre módulos y consultas ORM. Se revisaron
especialmente los flujos de autenticación, solicitudes y disponibilidad de
viajes. Los hallazgos históricos con rutas antiguas no se trataron como
diagnóstico vigente hasta verificarlos.

## Hallazgos y correcciones

| ID | Hallazgo verificado antes del cambio | Ubicación anterior | Corrección | Verificación |
|---|---|---|---|---|
| E1 | `requests` consultaba y mutaba directamente el ORM `Trip` al crear, aceptar, rechazar y retirar solicitudes. | `backend/app/modules/requests/application/create_request.py`; `manage_request.py` | `requests` ahora usa los contratos públicos de `trips.application`: lectura del contexto y reserva/liberación atómicas. | Pruebas de aceptación, cancelación, capacidad insuficiente y concurrencia en `backend/tests/test_requests_flow.py`. |
| E2 | El router de `trips` importaba la función privada `_to_response` desde el router de `requests`. | `backend/app/modules/trips/infrastructure/router.py` | `trips` define su esquema de resumen y arma su propia respuesta; ya no depende de un helper privado de otro router. | Búsqueda de imports entre routers y prueba del flujo de viajes/OpenAPI. |
| E3 | `auth` accedía directamente al ORM de `users` para iniciar sesión y resolver el usuario del token. | `backend/app/modules/auth/application/login.py`; `auth/infrastructure/security.py` | Consultas encapsuladas en servicios públicos de `users.application`; autenticación consume DTOs `UserCredentials` y `UserIdentity`, no el ORM. | Pruebas de registro, autenticación y flujos protegidos. |
| E4 | `users` dependía de `auth.infrastructure.security` para hashear contraseñas, creando dependencia circular potencial. | `backend/app/modules/users/application/create_user.py` | Primitivas de hash/verificación movidas a `backend/app/shared/security.py`, consumidas por ambos módulos. | Búsqueda de dependencias `users` → `auth` y pruebas de registro/login. |
| E5 | `auth.application.login` dependía de esquemas y utilidades de infraestructura de `auth`. | `backend/app/modules/auth/application/login.py` | El caso de uso recibe teléfono/contraseña como valores y crea tokens mediante el servicio de aplicación `auth.application.tokens`. | Revisión de imports por capa y pruebas de autenticación. |
| E6 | El documento de propiedad usaba rutas de modelos que ya no existen y describía el cambio de cupos como mutación directa por `requests`. | `docs/evidencia/propiedad_de_datos.md` | Se actualizaron rutas de modelos, titularidad de `seat_count` y de la disponibilidad, además del mecanismo público de aplicación. La tabla de violaciones antigua queda identificada como histórica. | Enlaces/rutas contrastados contra los archivos actuales y esta auditoría. |

## Límites aceptados

- La entidad `TripRequest` conserva una relación ORM de navegación con `Trip` para
  componer lecturas de solicitudes con información del viaje. `requests` no usa
  esa relación para modificar disponibilidad; las escrituras pasan por las
  operaciones públicas de `trips.application`.
- `trips` conserva `POST /trips/{trip_id}/reservations`, que realiza una reserva
  de un cupo dentro del módulo dueño de esa disponibilidad. El escenario está
  cubierto por `test_cupos.py` y por el ADR 0003; no se eliminó en esta Porción.
- Los routers consumen `UserIdentity` como principal de autenticación. La
  consulta ORM queda en `users.application`; la clase ORM no se comparte con
  `auth`, `requests` ni `trips` como contrato de usuario autenticado.
