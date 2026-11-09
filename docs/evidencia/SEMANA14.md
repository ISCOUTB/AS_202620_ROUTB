# Documentación del avance — Semana 14 · Medición y revisión de pares

## Resumen ejecutivo

La Semana 14 cierra con una **medición real y reproducible** del escenario de
Rendimiento declarado en arc42 §10.2 (`GET /trips/`, p95 < 3,99 s) y con la
incorporación de los señalamientos disponibles a arc42 §11. La medición se hizo
en dos entornos: el despliegue de Dokploy (medición principal) y una API local
con 5 viajes sembrados y PostgreSQL de pruebas (medición complementaria). Ambas
quedaron por debajo del umbral:

| Entorno | p95 más alto | Umbral | Conclusión |
|---|---:|---:|---|
| Dokploy (producción, carga útil vacía) | **631,76 ms** | 3.990 ms | **CUMPLE** |
| Local con 5 viajes y PostgreSQL de pruebas remoto | **2.564,52 ms** | 3.990 ms | **CUMPLE** |

El detalle del procedimiento, el entorno, las repeticiones, los resultados
crudos y las limitaciones está en
[`medicion-semana14.md`](medicion-semana14.md). Los scripts versionados son
[`scripts/medir_rendimiento.py`](../../scripts/medir_rendimiento.py) y
[`scripts/sembrar_viajes_medicion.py`](../../scripts/sembrar_viajes_medicion.py).

En arc42 §11 se agregó la subsección
[**11.4 Señalamientos de la revisión entre pares y de la revisión externa**](../arc42/11_riesgos_y_deuda_tecnica.md#114-señalamientos-de-la-revisión-entre-pares-y-de-la-revisión-externa).
Allí se distingue lo que señalaron los pares (no se recibieron comentarios
formales al cierre) de los hallazgos de la revisión externa que sí están
documentados, y cada fila tiene estado **Corregido**, **Asumido** o
**Pendiente** con su detalle.

## 1. Medición del escenario de rendimiento

- **Escenario:** un pasajero consulta los viajes disponibles con `GET /trips/`
  en condiciones normales de operación.
- **Umbral:** p95 < 3,99 s, tomado de
  [arc42 §10.2](../arc42/10_requisitos_de_calidad.md#102-escenarios-de-calidad)
  y no modificado después de medir.
- **Herramienta:** `scripts/medir_rendimiento.py` (Python 3.14 + `httpx`).
- **Carga:** 100 peticiones secuenciales por ronda × 3 rondas = 300 peticiones
  válidas por entorno, con calentamiento de `GET /health` y espera de 5 s.
- **Medición principal:** `https://routb.iscoutb.dev/trips/`, 2026-11-08
  23:15–23:19 (America/Bogota). `GET /trips/` devolvió `[]` (sin viajes activos).
- **Medición complementaria:** `http://127.0.0.1:8014/trips/`, API local con
  PostgreSQL 17.6 de pruebas en Supabase (`us-west-2`) y 5 viajes sembrados.
- **Resultado principal:** p95 más alto **631,76 ms** → **CUMPLE**.
- **Resultado complementario:** p95 más alto **2.564,52 ms** → **CUMPLE**, con
  pausas aisladas de la base remota que elevan los máximos pero no el p95.

## 2. Incorporación de la revisión a arc42 §11

La sección
[11.4](../arc42/11_riesgos_y_deuda_tecnica.md#114-señalamientos-de-la-revisión-entre-pares-y-de-la-revisión-externa)
contiene:

- **11.4.1 Revisión entre pares:** constancia explícita de que no se recibieron
  señalamientos formales del taller `arqsw:workshop-pares` al cierre. Se
  revisaron issues y pull requests del repositorio y no hay comentarios humanos
  de otros equipos. El estado de esta ausencia es **Asumido**, con la
  justificación y la disposición a incorporar los comentarios si llegan.
- **11.4.2 Hallazgos de la revisión externa:** siete hallazgos documentados en
  `ISCOUTB/AS_202620_feedback` (Sonar, medición de carga, migración 010,
  propiedad de datos entre `requests` y `trips`, FCM síncrono, verificación del
  despliegue y README). Cada uno tiene estado:
  - **Corregido:** medición de carga (E-2) y README de Render (E-7).
  - **Asumido:** FCM best-effort (E-5) y verificación del SHA desplegado (E-6).
  - **Pendiente:** Sonar real (E-1), migración 010 en producción (E-3) y
    actualización de ruta desde `requests` (E-4).

## 3. Matriz de cumplimiento S14

| Criterio de evaluación | Evidencia técnica esperada | Estado (Cumple / No cumple) | Observaciones |
|---|---|---|---|
| Escenario medido identificado, con el umbral declarado en arc42 sección 10 | escenario citado y su umbral | **Cumple** | `GET /trips/` citado con p95 < 3,99 s en [`medicion-semana14.md`](medicion-semana14.md#1-escenario-medido-y-umbral) y en [arc42 §10.2](../arc42/10_requisitos_de_calidad.md#102-escenarios-de-calidad). El umbral no se cambió después de medir. |
| Procedimiento de medición con herramienta, carga y repeticiones | script o apartado del procedimiento | **Cumple** | [`scripts/medir_rendimiento.py`](../../scripts/medir_rendimiento.py) + sección 2 de [`medicion-semana14.md`](medicion-semana14.md#2-procedimiento): 100 peticiones × 3 rondas, calentamiento y validación de HTTP 200. |
| Medición reproducible por otra persona | artefactos versionados de la medición | **Cumple** | Script de medición, script de siembra, comandos paso a paso y JSON crudos versionados en [`medicion-semana14.md`](medicion-semana14.md#7-reproducibilidad). |
| Resultado contrastado con el umbral, con conclusión explícita | cifra obtenida frente al umbral | **Cumple** | **631,76 ms < 3.990 ms → CUMPLE** en Dokploy; **2.564,52 ms < 3.990 ms → CUMPLE** en local. Conclusión explícita en las secciones 4 y 5 de la evidencia. |
| Entorno de la medición declarado | apartado que dice si fue local o desplegado | **Cumple** | Sección 3 de la evidencia: Dokploy (desplegado, externo) y local (API Windows + PostgreSQL de pruebas remoto), con SO, CPU, RAM, versiones, URL y limitaciones. |
| arc42 sección 11 con lo señalado por los pares | `docs/arc42/11*` y su historial | **Cumple** | §11.4 agregada en [`11_riesgos_y_deuda_tecnica.md`](../arc42/11_riesgos_y_deuda_tecnica.md#114-señalamientos-de-la-revisión-entre-pares-y-de-la-revisión-externa). **Salvedad:** no se recibieron señalamientos de pares; se deja constancia en §11.4.1 y se incorporan los hallazgos externos en §11.4.2. |
| Estado de cada señalamiento: corregido, asumido o pendiente | columna o apartado de estado | **Cumple** | Las dos tablas de §11.4 tienen columna **Estado**: P-0 Asumido; E-1 Pendiente; E-2 Corregido; E-3 Pendiente; E-4 Pendiente; E-5 Asumido; E-6 Asumido; E-7 Corregido. |
| Columna de evidencia del aspecto medido, apuntando a esta medición | fila de `docs/aspectos.md` | **Cumple** | Fila 1 de [`docs/aspectos.md`](../aspectos.md) agrega `[Medición Semana 14](evidencia/medicion-semana14.md)` en la columna *Evidencia*. |

**Recuento: 8 de 8 criterios cumplidos.** La salvedad de la fila 6 no oculta
información: el repositorio no tenía comentarios de pares y la sección 11 lo dice
explícitamente en lugar de inventar hallazgos.

## 4. Verificación ejecutada

- **Medición real:** 3 rondas × 100 peticiones en Dokploy y 3 rondas × 100 en
  local; todas las respuestas fueron `200`. Los JSON crudos están versionados.
- **Migraciones de la base de pruebas:** `alembic upgrade head` aplicado hasta
  `010_solicitud_activa_unica` antes de sembrar los viajes.
- **Limpieza:** los 5 viajes sembrados se retiraron con
  `sembrar_viajes_medicion.py --clean`.
- **Backend:** resultado de `pytest -q` al cierre en la sección 5.
- **Frontend:** no se modificó; no se ejecutaron `flutter analyze` ni
  `flutter test` porque el cambio es de documentación y scripts.
- **Git:** revisar `git diff` antes de commitear; los artefactos nuevos son
  scripts, JSON de resultados y documentos.

## 5. Estado de la suite del backend

{{PYTEST_STATUS}}

## 6. Referencias

- [Evidencia de medición](medicion-semana14.md)
- [Resultados crudos de Dokploy](medicion-semana14-dokploy.json)
- [Resultados crudos locales](medicion-semana14-local.json)
- [arc42 §10.2 — Escenarios de calidad](../arc42/10_requisitos_de_calidad.md#102-escenarios-de-calidad)
- [arc42 §11.4 — Señalamientos](../arc42/11_riesgos_y_deuda_tecnica.md#114-señalamientos-de-la-revisión-entre-pares-y-de-la-revisión-externa)
- [Tabla de aspectos](../aspectos.md)
- [`scripts/medir_rendimiento.py`](../../scripts/medir_rendimiento.py)
- [`scripts/sembrar_viajes_medicion.py`](../../scripts/sembrar_viajes_medicion.py)
