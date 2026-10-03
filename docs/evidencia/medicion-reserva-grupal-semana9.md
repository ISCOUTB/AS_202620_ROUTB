# Medición del escenario de calidad — Semana 9

## Escenario y umbral

Se conserva el escenario publicado para `GET /trips/`: servicio caliente, mínimo 100 respuestas HTTP 200 y **p95 < 3,99 s**. La medición oficial de producción es interna, con los logs estructurados de Render; la externa de PowerShell incluye la red. Procedimiento completo y línea base en [métricas de calidad](metricas-escenario-calidad.md).

## Línea base publicada

El 26 de septiembre de 2026, antes de esta Porción, se reportaron 100 respuestas 200 a `GET /trips/`: p95 interno 219,80 ms y p95 externo 585,10 ms. La línea base cumple el umbral. No se debe comparar directamente una medición local con estos valores de producción ni atribuir una diferencia al cambio de reserva grupal si no se midió el mismo despliegue y escenario.

## Comparación externa

Escenario: `GET https://as-202620-routb.onrender.com/trips/`, servicio
caliente y respuestas HTTP 200.

| Dato | Línea base | Semana 9 |
|---|---:|---:|
| Fuente | Script de PowerShell con `curl` | Script de PowerShell con `curl` |
| Peticiones con código 200 (N) | 100 | 100 |
| Mínimo | 426,80 ms | 502,53 ms |
| Promedio | 507,70 ms | 590,82 ms |
| **p95** | **585,10 ms** | **697,82 ms** |
| Máximo | 724,40 ms | 904,64 ms |
| Umbral | < 3.990 ms | < 3.990 ms |
| **Resultado** | **CUMPLE** | **CUMPLE** |

El p95 de la línea base fue 585,10 ms y el de Semana 9 fue 697,82 ms; ambos
están por debajo del umbral de 3.990 ms. En Semana 9, el mínimo fue 502,53 ms,
el promedio 590,82 ms y el máximo 904,64 ms. Frente a la línea base, el p95
aumentó 112,72 ms (19,3 %) y el máximo aumentó 180,24 ms (24,9 %). La medición
de Semana 9 es externa y complementaria; la medición interna oficial con logs
de Render sigue pendiente.
