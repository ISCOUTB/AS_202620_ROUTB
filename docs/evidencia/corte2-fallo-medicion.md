# Semana 10, corte 2: medición con fallo inyectado

## Estado

Pendiente de ejecución. No se reportan cifras hasta correr las pruebas y las 50
solicitudes en un entorno con PostgreSQL de pruebas configurado.

## Verificación automatizada

- `pytest tests/test_routing.py tests/test_openapi_contract.py -q`: **10
  pruebas pasaron** (incluye la consulta PostgreSQL de TTL); dos advertencias.
- La suite completa quedó pendiente de una aprobación adicional para su segunda
  ejecución local. Se ejecutará en CI con la base PostGIS efímera del workflow.
- La medición de endpoint quedó implementada en
  `test_matching_osrm_timeout_50_responses_remain_contractual`: inyecta timeout,
  envía 50 solicitudes, valida HTTP/esquema y registra p95. Su resultado queda
  pendiente de la ejecución CI; no se infieren cifras de otras pruebas.

## Registro

| Escenario | Commit | N | HTTP 500 | % contractual | p95 (s) | Umbral | Resultado |
|---|---|---:|---:|---:|---:|---:|---|
| Sin fallo (base) | Pendiente | 50 | Pendiente | Pendiente | Pendiente | < 3.99 s | Pendiente |
| Timeout/fallo OSRM | Pendiente | 50 | Pendiente | Pendiente | Pendiente | < 3.99 s | Pendiente |

La medición debe inyectar el timeout mediante mock/monkeypatch, validar las
respuestas con el esquema/OpenAPI y obtener latencias `duration_ms` del
middleware. La evidencia histórica de calidad se referencia en
`metricas-escenario-calidad.md`; no se reutilizan sus cifras como resultados de
este escenario.
