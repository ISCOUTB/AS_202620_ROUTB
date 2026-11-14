# 9. Decisiones arquitectónicas

Las decisiones arquitectónicas que impactan significativamente la estructura, la integración, el mantenimiento, la escalabilidad y el despliegue del sistema ROUTB se formalizan en los siguientes Registros de Decisiones Arquitectónicas (ADR):

| ADR | Estado | Decisión |
|---|---|---|
| [ADR 0001](../adr/0001-usar-monolito-modular.md) | Aceptado | Adoptar un monolito modular como estilo arquitectónico para el backend de ROUTB. |
| [ADR 0002](../adr/0002-usar-arquitectura-interna-por-capas.md) | Aceptado | Usar una arquitectura interna por capas para estructurar la lógica dentro de cada módulo. |
| [ADR 0003](../adr/0003-control-atomico-de-cupos.md) | Aceptado | Usar una actualización atómica condicionada en SQL para evitar la sobreventa de cupos. |
| [ADR 0004](../adr/0004-integracion-sincrona-rest.md) | Aceptado | Usar integración síncrona mediante API REST sobre HTTPS para la comunicación de clientes y servicios. |
| [ADR 0005](../adr/0005-render-plataforma-de-despliegue.md) | Reemplazado por [ADR 0015](../adr/0015-dokploy-plataforma-de-despliegue.md) | Adoptar Render (Free Web Service) como plataforma de cómputo y despliegue del backend contenerizado. |
| [ADR 0006](../adr/0006-base-de-datos-supabase.md) | Aceptado | Adoptar Supabase (Free Tier) como plataforma de base de datos relacional PostgreSQL administrada. |
| [ADR 0007](../adr/0007-reserva-grupal-de-cupos.md) | Aceptado | Aceptar la reserva grupal de cupos como mecanismo para permitir que los usuarios reserven múltiples cupos en una sola transacción. |
| [ADR 0008](../adr/0008-no-componente-generativo.md) | Aceptado | Rechazar la implementación de un componente generativo en el sistema. |
| [ADR 0009](../adr/0009-postgis-datos-geoespaciales.md) | Aceptado | Habilitar PostGIS para almacenar, indexar y consultar coordenadas, rutas y demás datos geoespaciales de ROUTB. |
| [ADR 0010](../adr/0010-geocodificacion-y-cache.md) | Reemplazado por [ADR 0018](../adr/0018-google-maps-platform-frontend.md) | Usar Photon como proveedor principal de geocodificación, Nominatim como respaldo y PostgreSQL como caché de consultas. |
| [ADR 0011](../adr/0011-consentimiento-y-privacidad-de-ubicacion.md) | Aceptado | Pedir consentimiento para usar ubicaciones exactas y aplicar retención, revocación y purga de los datos geoespaciales. |
| [ADR 0012](../adr/0012-sugerencias-matching-y-orden-de-paradas.md) | Aceptado | Sugerir viajes compatibles con scoring y ETA mediante matching de solo lectura, con aprobación final del conductor y paradas ordenadas a lo largo de la ruta. |
| [ADR 0013](../adr/0013-notificaciones-push-fcm.md) | Aceptado | Avisar por push con FCM como canal complementario a REST, sin romper el flujo si FCM falla y borrando tokens inválidos. |
| [ADR 0014](../adr/0014-fallback-geocode-cache.md) | Aceptado; geocodificación reemplazada por [ADR 0018](../adr/0018-google-maps-platform-frontend.md) | Configurar el timeout de routing y no retener fallbacks degradados en la caché de rutas. |
| [ADR 0015](../adr/0015-dokploy-plataforma-de-despliegue.md) | Aceptado | Desplegar el backend contenedorizado en Dokploy, sobre un servidor propio, con dominio propio y TLS automático. |
| [ADR 0016](../adr/0016-ventana-de-viajes-hoy-manana.md) | Aceptado | Limitar la publicación y la búsqueda de viajes a hoy y mañana para concentrar la oferta en una comunidad pequeña. |
| [ADR 0017](../adr/0017-decision-extraccion-modulo-requests.md) | Aceptado | No extraer el módulo requests a microservicio independiente para preservar la consistencia atómica de cupos y la viabilidad operativa a costo cero. |
| [ADR 0018](../adr/0018-google-maps-platform-frontend.md) | Aceptado | Resolver geocodificación, autocompletado y rutas en el cliente Flutter con Google Maps Platform; retirar la geocodificación del backend. |
| [ADR 0019](../adr/0019-renderizado-mapas-flutter-map-osm.md) | Aceptado | Renderizar el mapa con `flutter_map` y teselas de OpenStreetMap, separado del proveedor de datos. |
| [ADR 0020](../adr/0020-decision-datos-mas-costosa-de-revertir.md) | Aceptado | Identificar el esquema de estados de solicitudes y control atómico de cupos como la decisión de datos más costosa de revertir, y documentar el costo comparativo de reversión de las cuatro principales decisiones de datos del sistema. |
| [ADR 0021](../adr/0021-integridad-solicitudes-y-concurrencia.md) | Aceptado | Garantizar una sola solicitud activa por pasajero y viaje con un índice único parcial y verificar la concurrencia del flujo crear → aceptar. |
| [ADR 0022](../adr/0022-desacoplamiento-asincrono-notificaciones.md) | Aceptado como prototipo | Desacoplamiento temporal y mensajería asíncrona para notificaciones push ante eventos de viaje (prototipo aislado). |
| [ADR 0023](../adr/0023-estrategia-de-seguridad-stride-y-auditoria-de-dependencias.md) | Aceptado | Adoptar el modelado de amenazas STRIDE anclado en C4 y la auditoría automatizada de vulnerabilidades en dependencias con pip-audit en CI. |
| [ADR 0024](../adr/0024-unicidad-de-telefono.md) | Aceptado | Garantizar un solo usuario por teléfono con el índice único `uq_users_phone`, normalizando a 10 dígitos y abortando la migración si hay duplicados. |
| [ADR 0025](../adr/0025-despacho-push-con-background-tasks.md) | Aceptado | Despachar las notificaciones push con `BackgroundTasks` después del `commit`, con una tarea de fondo autónoma y entrega *at-most-once*. |
| [ADR 0026](../adr/0026-datos-vehiculo-y-visibilidad.md) | Aceptado | Registrar modelo, color y placa del vehículo como datos opcionales del conductor y exponerlos solo al pasajero con solicitud aceptada. |

---
