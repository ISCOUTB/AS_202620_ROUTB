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
| [ADR 0010](../adr/0010-geocodificacion-y-cache.md) | Aceptado | Usar Photon como proveedor principal de geocodificación, Nominatim como respaldo y PostgreSQL como caché de consultas. |
| [ADR 0011](../adr/0011-consentimiento-y-privacidad-de-ubicacion.md) | Aceptado | Pedir consentimiento para usar ubicaciones exactas y aplicar retención, revocación y purga de los datos geoespaciales. |
| [ADR 0012](../adr/0012-sugerencias-matching-y-orden-de-paradas.md) | Aceptado | Sugerir viajes compatibles con scoring y ETA mediante matching de solo lectura, con aprobación final del conductor y paradas ordenadas a lo largo de la ruta. |
| [ADR 0013](../adr/0013-notificaciones-push-fcm.md) | Aceptado | Avisar por push con FCM como canal complementario a REST, sin romper el flujo si FCM falla y borrando tokens inválidos. |
| [ADR 0014](../adr/0014-fallback-geocode-cache.md) | Aceptado | Configurar el timeout de routing y no retener fallbacks degradados en la caché de rutas. |
| [ADR 0015](../adr/0015-dokploy-plataforma-de-despliegue.md) | Aceptado | Desplegar el backend contenedorizado en Dokploy, sobre un servidor propio, con dominio propio y TLS automático. |
| [ADR 0016](../adr/0016-ventana-de-viajes-hoy-manana.md) | Aceptado | Limitar la publicación y la búsqueda de viajes a hoy y mañana para concentrar la oferta en una comunidad pequeña. |
| [ADR 0017](../adr/0017-decision-extraccion-modulo-requests.md) | Aceptado | No extraer el módulo requests a microservicio independiente para preservar la consistencia atómica de cupos y la viabilidad operativa a costo cero. |

---
