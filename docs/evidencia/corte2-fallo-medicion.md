# Semana 10, corte 2: medición con fallo inyectado

## Estado

Medición local ejecutada el 13 de octubre de 2026 contra la base de pruebas
(Supabase/PostGIS) con el código de `66c8250`, más temporización directa
contra host que no responde. Los valores de p95 quedan transcritos abajo; ya
no se presentan como aserción sin número.

Historial de CI: la corrida inicial
[38323128005](https://github.com/ISCOUTB/AS_202620_ROUTB/actions/runs/38323128005)
y la registrada para `e1bae37`
[38323835408](https://github.com/ISCOUTB/AS_202620_ROUTB/actions/runs/38323835408)
aprobaron el job backend y el contrato OpenAPI. Sonar falló en ambas; por
tanto, el resultado general de CI sigue en rojo y el redespliegue sujeto a
checks sigue pendiente.

## Verificación automatizada

- `test_matching_50_responses_remain_contractual`: compara 50 solicitudes con
  OSRM simulado disponible y 50 con timeout a `/matching/suggestions`; exige
  HTTP 200, respuesta contractual y el valor de `degraded` esperado, y mide la
  latencia observada por `TestClient`.
- Pruebas nuevas con `timeout` en el nombre: `test_call_osrm_timeout_falls_back_degraded_without_cache`
  (timeout → respaldo sin persistir), `test_geocode_timeout_uses_configured_timeout`
  (Photon/Nominatim usan `ROUTING_TIMEOUT_SECONDS`) y
  `test_geocode_timeout_photon_falls_back_to_nominatim` (cadena real de respaldo).
- Hallazgo corregido durante la medición: las dos ramas colisionaban en
  `route_cache` porque `_coords_key` redondea a 5 decimales y la base de
  pruebas es compartida; la rama con fallo leía la ruta sana de la rama base.
  Se aislaron las ramas con bases de latitud separadas por caso
  (`test_matching_suggestions.py`). Una repetición posterior en paralelo con
  otra suite confirmó la lección: solo una suite a la vez contra la base de
  pruebas (el teardown concurrente tumbó las tablas del rerun).

## Registro

| Escenario | Commit | N | HTTP 500 | % contractual | p95 (s) | Umbral | Resultado |
|---|---|---:|---:|---:|---:|---:|---|
| Sin fallo (base) | `66c8250` | 50 | 0 | 100 % | 1,6368 | < 3,99 s | **CUMPLE** |
| Timeout/fallo OSRM | `66c8250` | 50 | 0 | 100 % | 2,7047 | < 3,99 s | **CUMPLE** |

Repetición de confirmación (misma sesión de código, base compartida):
sin_fallo p95=1,5645 s. La rama con fallo de esa repetición quedó invalidada
por contaminación entre sesiones concurrentes (ver punto anterior), no por el
código.

## Comparación de timeouts (latencia real, host `10.255.255.1`)

| Llamada | T=3,0 s medido | T=1,4 s medido |
|---|---:|---:|
| `_call_osrm` | 3,24 s → `None` (respaldo) | 1,42 s → `None` (respaldo) |
| `_call_photon` | 3,03 s → `None` (respaldo) | 1,43 s → `None` (respaldo) |
| Peor caso geocode (2T+1,05) | ≈ 7,1 s → **supera 3,99 s** | ≈ 3,9 s → **bajo 3,99 s** |

Por eso el default de `ROUTING_TIMEOUT_SECONDS` pasa de `3.0` a `1.4`
([ADR 0014](../adr/0014-fallback-geocode-cache.md)). La medición con OSRM
simulado prueba contrato y umbral; la temporización directa prueba el límite
de latencia. La evidencia histórica de calidad se referencia en
`metricas-escenario-calidad.md`; no se reutilizan sus cifras como resultados
de este escenario.

## Producción y decisiones pendientes

En la verificación de producción del 12 de octubre de 2026, `GET /health`
respondió HTTP 200 y `GET /openapi.json` respondió HTTP 200 con versión 0.6.0 y
20 rutas. No se obtuvo la versión de commit servida ni se validó la base de
producción. Las migraciones aprobadas en CI usaron una base efímera, por lo que
no equivalen a ejecutar o comprobar migraciones en producción.

Pendientes del equipo: Quality Gate de Sonar en verde, merge a `master` con
redespliegue y verificación (commit servido, migraciones en `head`), y prueba
push con la app cerrada en dispositivo Android real.
