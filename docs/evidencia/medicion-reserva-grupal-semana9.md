# Medición del escenario de calidad — Semana 9

## Escenario y umbral

Se conserva el escenario publicado para `GET /trips/`: servicio caliente, mínimo 100 respuestas HTTP 200 y **p95 < 3,99 s**. La medición oficial de producción es interna, con los logs estructurados de Render; la externa de PowerShell incluye la red. Procedimiento completo y línea base en [métricas de calidad](metricas-escenario-calidad.md).

## Línea base publicada

El 26 de septiembre de 2026, antes de esta Porción, se reportaron 100 respuestas 200 a `GET /trips/`: p95 interno 219,80 ms y p95 externo 585,10 ms. La línea base cumple el umbral. No se debe comparar directamente una medición local con estos valores de producción ni atribuir una diferencia al cambio de reserva grupal si no se midió el mismo despliegue y escenario.

## Medición posterior a la implementación

El 2 de octubre de 2026 (hora de Bogotá) se ejecutó una medición local posterior con el servicio caliente. Se calentó `/health` y después se midió el tiempo percibido por `TestClient` para 100 consultas a `GET /trips/`; las 100 respondieron 200.

| Entorno/fecha | N 200 | p95 | Umbral | Fuente | Resultado |
|---|---:|---:|---:|---|---|
| Local, SQLite temporal; 2026-10-02 | 100 | 0,0762 s | < 3,99 s | `TestClient`, tiempo total cliente-servidor local | CUMPLE |

La medición local cumple el umbral publicado en este escenario, pero no es comparable directamente con Render: no incluye la misma infraestructura ni la latencia de red. Como no se desplegó esta versión, no se atribuye una mejora a la Porción y queda pendiente repetir la medición interna oficial en Render cuando se desplieguen los cambios.

Reproducción automatizada: `backend/tests/test_week9_quality_measurement.py`. El test informó `N=100, p95=0.0762s, umbral=3.99s` y pasó (`1 passed`).
