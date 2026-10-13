# Semana 10, corte 2: medición con fallo inyectado

## Estado

Medición ejecutada en CI el 12 de octubre de 2026 contra PostgreSQL/PostGIS
efímero. La corrida inicial
[38323128005](https://github.com/ISCOUTB/AS_202620_ROUTB/actions/runs/38323128005)
y la corrida más reciente registrada para `e1bae37`
[38323835408](https://github.com/ISCOUTB/AS_202620_ROUTB/actions/runs/38323835408)
aprobaron el job backend y el contrato OpenAPI. Sonar falló en ambas; por tanto,
el resultado general de CI sigue en rojo y Render, configurado para desplegar
cuando pasen los checks, no pudo redesplegar.

El log accesible en esta revisión no expone los valores numéricos exactos del
p95. Solo se puede afirmar que la aserción `p95 < 3.99 s` pasó en ambos
escenarios. No se presenta ese límite como un valor medido.

## Verificación automatizada

- La suite backend completa y la prueba de contrato OpenAPI pasaron en la
  corrida CI más reciente (`e1bae37`); el ciclo Alembic se ejecutó en la base
  efímera de CI. Esto no valida el estado de migraciones de producción.
- La suite local contra una base remota no se ejecutó; no se contaba con una
  credencial aprobada para esa base.
- La medición del endpoint quedó implementada en
  `test_matching_50_responses_remain_contractual`: compara 50 solicitudes con
  OSRM simulado disponible y 50 con timeout a `/matching/suggestions`; exige
  HTTP 200, respuesta contractual y el valor de `degraded` esperado, y mide la
  latencia observada por `TestClient`. El job confirma que ambos p95 quedaron
  bajo `3.99 s`, pero no se transcriben valores exactos porque no están
  disponibles en el log consultado.

## Registro

| Escenario | Commit | N | HTTP 500 | % contractual | p95 (s) | Umbral | Resultado |
|---|---|---:|---:|---:|---:|---:|---|
| Sin fallo (base) | `64986a2` | 50 | 0 | 100 % | No disponible; aserción pasó | < 3.99 s | Pasa aserción |
| Timeout/fallo OSRM | `64986a2` | 50 | 0 | 100 % | No disponible; aserción pasó | < 3.99 s | Pasa aserción |

La medición simula el éxito y el timeout con `monkeypatch` y registra latencia
observada por `TestClient`; no es una medición del tiempo real de espera de OSRM
ni sirve para comparar defaults de timeout de `1.4 s` y `3.0 s`. Aunque el
workflow publica las líneas p95 en el resumen del job, los números exactos no
quedaron disponibles en la consulta efectuada. La evidencia histórica de
calidad se referencia en `metricas-escenario-calidad.md`; no se reutilizan sus
cifras como resultados de este escenario.

## Producción y decisiones pendientes

En la verificación de producción del 12 de octubre de 2026, `GET /health`
respondió HTTP 200 y `GET /openapi.json` respondió HTTP 200 con versión 0.6.0 y
20 rutas. No se obtuvo la versión de commit servida ni se validó la base de
producción. Las migraciones aprobadas en CI usaron una base efímera, por lo que
no equivalen a ejecutar o comprobar migraciones en producción.

El timeout configurable conserva actualmente `3.0 s`, el valor que ya tenía la
llamada OSRM antes del cambio. Esta continuidad explica la elección provisional,
pero no demuestra que `3.0 s` sea mejor que el `1.4 s` planteado en el plan.
La medición con OSRM simulado tampoco justifica ninguno de los dos valores; el
default queda sujeto a decisión y a una medición real controlada.
