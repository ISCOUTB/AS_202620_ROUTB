# ADR 0014: Timeout de routing y caché resiliente ante fallos

## Estado

Aceptado; validado por pruebas automatizadas y temporización real el 13 de
octubre de 2026. El timeout predeterminado queda fijado en `1.4` s.

## Contexto

El cálculo de rutas usa OSRM y una caché PostgreSQL de 24 horas. La consulta del
TTL expresaba el intervalo como `INTERVAL ':h hours'`, donde `:h` quedaba dentro
de un literal SQL. Además, el timeout HTTP estaba fijado en el código (`3.0` s
en OSRM, Photon y Nominatim). Si OSRM fallaba, el respaldo geodésico se guardaba
como si fuera una ruta de proveedor, por lo que podía seguir ocultando la
recuperación de OSRM durante 24 horas. Con `3.0` s, el peor caso de
geocodificación (Photon + espera + Nominatim) tarda ≈ 7 s y rompe el umbral
p95 de 3,99 s.

## Decisión

- Timeout único `ROUTING_TIMEOUT_SECONDS` con valor por defecto `1.4` s,
  aplicado a OSRM, Photon y Nominatim. Peor caso de geocodificación:
  2 × 1,4 + 1,05 = 3,85 s < 3,99 s. Temporización real contra host que no
  responde: con 3,0 s → OSRM 3,24 s y Photon 3,03 s; con 1,4 s → 1,42 s y
  1,43 s.
- Parametrizar el TTL como `:h * INTERVAL '1 hour'`.
- No persistir resultados con `degraded=true`; sí conservar en caché las rutas
  válidas de OSRM durante el TTL existente de 24 horas. También se ignoran
  entradas degradadas que ya estén presentes en caché.
- Mantener el respaldo geodésico y el contrato HTTP actuales. No se agregan
  reintentos automáticos ni cambios al contrato OpenAPI.

## Alternativas consideradas

- Mantener `3.0` s: descartado porque el peor caso de geocodificación (≈ 7 s)
  supera el umbral p95 de 3,99 s (medición real del 13-10-2026).
- Persistir el fallback: descartado porque una caída transitoria retendría una
  ruta aproximada hasta vencer el TTL.
- Reintentar OSRM varias veces: descartado porque aumenta la latencia y la carga
  sobre el proveedor, especialmente en el despliegue gratuito.

## Consecuencias y verificación

La recuperación del proveedor puede reflejarse en la siguiente solicitud que
requiera esa ruta. Las pruebas backend y OpenAPI, incluyendo el ciclo de
migraciones contra la base efímera de CI, se ejecutan en la corrida registrada
en `docs/evidencia/corte2-fallo-medicion.md`. La medición N=50 contra
`/matching/suggestions` confirma `500=0`, 100 % contractual y p95 bajo 3,99 s
en ambas ramas; la temporización directa confirma el peor caso bajo el umbral
con el default de `1.4` s. El Quality Gate de Sonar y la validación de
migraciones en producción siguen pendientes (ver
`docs/evidencia/corte2-fallo-medicion.md`).

Esta decisión complementa el respaldo de geocodificación de [ADR 0010](0010-geocodificacion-y-cache.md)
y la resiliencia de routing descrita en [ADR 0012](0012-sugerencias-matching-y-orden-de-paradas.md).
