# Semana 10, corte 2: medición con fallo inyectado

## Estado

Medición ejecutada en CI el 12 de octubre de 2026 contra PostgreSQL/PostGIS
efímero. La [corrida 38323128005](https://github.com/ISCOUTB/AS_202620_ROUTB/actions/runs/38323128005)
terminó con el job backend y el contrato OpenAPI aprobados. El job de Sonar
falló, por lo que Render no pudo desplegar al estar configurado para esperar los
checks. La salida con el p95 exacto no es visible mediante el acceso público
disponible; el test sí pasó la aserción `p95 < 3.99 s` en ambos escenarios.

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
| Sin fallo (base) | `64986a2` | 50 | 0 | 100 % | < 3.99 s (aserción CI; p95 exacto no visible) | < 3.99 s | Cumple |
| Timeout/fallo OSRM | `64986a2` | 50 | 0 | 100 % | < 3.99 s (aserción CI; p95 exacto no visible) | < 3.99 s | Cumple |

La medición simula el éxito y el timeout con `monkeypatch` y registra latencia
observada por `TestClient`; el workflow publica las dos líneas p95 en el resumen
del job. También ejecuta por separado `test_openapi_contract.py`. La evidencia
histórica de calidad se referencia en `metricas-escenario-calidad.md`; no se
reutilizan sus cifras como resultados de este escenario.
