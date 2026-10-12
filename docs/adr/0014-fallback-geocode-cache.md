# ADR 0014: Timeout de routing y caché resiliente ante fallos

## Estado

Aceptado (implementación local pendiente de validación automatizada y medición).

## Contexto

El cálculo de rutas usa OSRM y una caché PostgreSQL de 24 horas. La consulta del
TTL expresaba el intervalo como `INTERVAL ':h hours'`, donde `:h` quedaba dentro
de un literal SQL. Además, el timeout HTTP estaba fijado en el código. Si OSRM
fallaba, el respaldo geodésico se guardaba como si fuera una ruta de proveedor,
por lo que podía seguir ocultando la recuperación de OSRM durante 24 horas.

## Decisión

- Parametrizar el TTL como `:h * INTERVAL '1 hour'`.
- Configurar el timeout de OSRM con `ROUTING_TIMEOUT_SECONDS` (por defecto,
  `3.0` segundos).
- No persistir resultados con `degraded=true`; sí conservar en caché las rutas
  válidas de OSRM durante el TTL existente de 24 horas. También se ignoran
  entradas degradadas que ya estén presentes en caché.
- Mantener el respaldo geodésico y el contrato HTTP actuales. No se agregan
  reintentos automáticos ni cambios al contrato OpenAPI.

## Alternativas consideradas

- Persistir el fallback: descartado porque una caída transitoria retendría una
  ruta aproximada hasta vencer el TTL.
- Reintentar OSRM varias veces: descartado porque aumenta la latencia y la carga
  sobre el proveedor, especialmente en el despliegue gratuito.

## Consecuencias y verificación

La recuperación del proveedor puede reflejarse en la siguiente solicitud que
requiera esa ruta. La consulta del TTL y el timeout se cubrirán con pruebas; la
medición de latencia con fallo inyectado se registra en
`docs/evidencia/corte2-fallo-medicion.md` cuando se ejecute en un entorno
disponible.

Esta decisión complementa el respaldo de geocodificación de [ADR 0010](0010-geocodificacion-y-cache.md)
y la resiliencia de routing descrita en [ADR 0012](0012-sugerencias-matching-y-orden-de-paradas.md).
