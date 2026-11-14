# ADR 0027: Retirar el consentimiento propio de ubicación

## Estado

Aceptado. Reemplaza parcialmente el
[ADR 0011](0011-consentimiento-y-privacidad-de-ubicacion.md).

## Contexto

El [ADR 0011](0011-consentimiento-y-privacidad-de-ubicacion.md) introdujo un
consentimiento propio de ROUTB: una columna `location_consent_at`, dos endpoints
para otorgarlo o revocarlo y un bloqueo `403 location_consent_required` en las
operaciones que usan coordenadas. En la práctica, la app pedía dos permisos
distintos para la misma capacidad: el del sistema operativo y el suyo propio.

Mantener ambos mecanismos duplica pantallas, estados y pruebas, y confunde a la
persona usuaria cuando uno está activo y el otro no. El permiso del sistema
operativo ya es el control efectivo para acceder a la ubicación del dispositivo.

## Decisión

1. **Un solo control:** el permiso de ubicación del sistema operativo es el
   único requisito para usar las funciones que necesitan coordenadas. ROUTB deja
   de pedir, registrar o revocar un consentimiento propio.
2. **API:** se eliminan `POST /users/me/location-consent` y
   `DELETE /users/me/location-consent`, los códigos `403
   location_consent_required` y el campo `location_consent_at` de las respuestas
   de autenticación y de usuarios.
3. **Esquema:** una migración Alembic nueva elimina la columna
   `users.location_consent_at`. No se edita la migración 006 que la creó.
4. **Frontend:** se eliminan la pantalla de privacidad de ubicación, el diálogo
   de consentimiento y las verificaciones asociadas. En su lugar, el Perfil
   muestra el estado de los permisos del sistema y ofrece abrir los ajustes
   cuando están desactivados (G20). Los flujos que necesitan ubicación avisan y
   ofrecen ajustes en el momento en que se usan, sin pedir permisos al inicio.
5. **Se conserva:** la ofuscación de coordenadas antes de aceptar una solicitud,
   la retención máxima de 30 días y la purga periódica de geometrías. Ninguna de
   esas medidas dependía de la pantalla de consentimiento.

## Consecuencias

- **Cambio incompatible:** los clientes que llamaban a los endpoints de
  consentimiento deben dejar de hacerlo. La versión del contrato OpenAPI sube y
  el cambio se registra en `docs/evidencia/CHANGELOG-api.md`.
- **Menos duplicación:** una sola fuente de verdad para el permiso, menos
  estados imposibles y menos pruebas dedicadas al consentimiento propio.
- **Privacidad:** la autorización se gestiona en los ajustes del dispositivo; la
  app no conserva una marca temporal propia de consentimiento. Se mantienen la
  minimización, la ofuscación y la purga de datos geográficos.
- **Experiencia:** si el permiso está denegado, la persona ve un aviso claro y un
  acceso directo a los ajustes del celular, en lugar de una pantalla intermedia.

## Referencias

- [ADR 0011](0011-consentimiento-y-privacidad-de-ubicacion.md): consentimiento,
  retención y purga (reemplazado parcialmente).
- [ADR 0018](0018-google-maps-platform-frontend.md): geocodificación en el
  cliente.
- `backend/migrations/versions/014_remove_location_consent.py`
- `frontend/lib/core/widgets/routb_permission_status.dart`
