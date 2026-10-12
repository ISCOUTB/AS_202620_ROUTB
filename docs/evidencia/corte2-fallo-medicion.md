# Semana 10, corte 2: medición con fallo inyectado

## Estado

Pendiente de ejecución. No se reportan cifras hasta correr las pruebas y las 50
solicitudes en un entorno con PostgreSQL de pruebas configurado.

## Verificación automatizada

- `pytest tests/test_routing.py tests/test_openapi_contract.py -q`: **10
  pruebas pasaron** (incluye la consulta PostgreSQL de TTL); dos advertencias.
- La suite completa quedó pendiente de una aprobación adicional para su segunda
  ejecución local. Se ejecutará en CI con la base PostGIS efímera del workflow.
- La medición del endpoint quedó implementada en
  `test_matching_50_responses_remain_contractual`: compara 50 solicitudes con
  OSRM simulado disponible y 50 con timeout a `/matching/suggestions`; exige
  HTTP 200, respuesta contractual y el valor de `degraded` esperado, y mide la
  latencia observada por `TestClient`. Los resultados numéricos quedan
  pendientes de CI; no se infieren cifras de otras pruebas ni del middleware.

## Registro

| Escenario | Commit | N | HTTP 500 | % contractual | p95 (s) | Umbral | Resultado |
|---|---|---:|---:|---:|---:|---:|---|
| Sin fallo (base) | Pendiente | 50 | Pendiente | Pendiente | Pendiente | < 3.99 s | Pendiente |
| Timeout/fallo OSRM | Pendiente | 50 | Pendiente | Pendiente | Pendiente | < 3.99 s | Pendiente |

La medición se ejecuta en CI contra PostgreSQL/PostGIS efímero, simula el éxito y
el timeout con `monkeypatch` y registra latencia observada por `TestClient`. El
job también ejecuta por separado `test_openapi_contract.py`. La evidencia histórica
de calidad se referencia en `metricas-escenario-calidad.md`; no se reutilizan
sus cifras como resultados de este escenario.
