# ADR 0014: Timeout de routing y caché resiliente ante fallos

## Estado

Aceptado; validado por pruebas automatizadas en CI. La elección del timeout
predeterminado sigue provisional y su comparación de rendimiento está pendiente.

## Contexto

El cálculo de rutas usa OSRM y una caché PostgreSQL de 24 horas. La consulta del
TTL expresaba el intervalo como `INTERVAL ':h hours'`, donde `:h` quedaba dentro
de un literal SQL. Además, el timeout HTTP estaba fijado en el código. Si OSRM
fallaba, el respaldo geodésico se guardaba como si fuera una ruta de proveedor,
por lo que podía seguir ocultando la recuperación de OSRM durante 24 horas.

## Decisión

- Parametrizar el TTL como `:h * INTERVAL '1 hour'`.
- Configurar el timeout de OSRM con `ROUTING_TIMEOUT_SECONDS` (por defecto,
  `3.0` segundos, conservando el valor previo codificado). Este default es una
  decisión de compatibilidad provisional: la medición disponible no demuestra
  que `3.0` sea preferible al objetivo de `1.4` segundos planteado en el plan.
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
requiera esa ruta. Las pruebas backend y OpenAPI, incluyendo el ciclo de
migraciones contra la base efímera de CI, pasaron en la corrida registrada en
`docs/evidencia/corte2-fallo-medicion.md`. Sonar no pasó y las migraciones de
producción no se comprobaron. La medición con OSRM simulado prueba el contrato y
el umbral p95 de 3.99 s, pero no incluye los valores exactos ni compara los
timeouts de 1.4 s y 3.0 s; esa evaluación queda pendiente.

Esta decisión complementa el respaldo de geocodificación de [ADR 0010](0010-geocodificacion-y-cache.md)
y la resiliencia de routing descrita en [ADR 0012](0012-sugerencias-matching-y-orden-de-paradas.md).
