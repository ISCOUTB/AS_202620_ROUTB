# Documentación del avance — Semana 12

## Resumen ejecutivo

La Semana 12 concentró dos bloques de trabajo. Durante la semana se completó el
traslado de la geocodificación y el ruteo al cliente: la app pasó a resolver
direcciones, autocompletado y rutas con Google Maps Platform, y el backend
retiró el módulo `geocode`, el endpoint `GET /geocode/search`, el servicio
compartido y la tabla `geocode_cache`. Esa decisión quedó registrada en los
ADR 0018 y 0019 y se acompañó con la limpieza de pruebas, la regeneración del
contrato OpenAPI y la actualización de la documentación de arquitectura y
costos.

Al cierre de la semana se atendió la revisión de arquitectura en tres frentes:
(1) conciliar arc42 y los ADR con la caché de geocodificación del cliente y con
el funcionamiento vigente de `route_cache`; (2) actualizar la guía de despliegue
de Render a Dokploy; y (3) verificar la integridad y consistencia de las
solicitudes de viaje y de los cupos bajo peticiones simultáneas. Como resultado
se agregó el ADR 0021, la migración `010_solicitud_activa_unica`, cinco pruebas
de concurrencia del flujo real crear → aceptar y el endurecimiento de las
transiciones de aceptar/rechazar. El cierre quedó registrado en el commit
[`48ba676`](#13-commit-de-cierre).

## 1. Trabajo de la semana

### 1.1 Migración de mapas al cliente y retiro de la geocodificación del backend

| Fecha | Commit | Aporte |
|---|---|---|
| 2026-10-21 | `c7bba5e` | Widgets y pantallas Flutter, pruebas de cliente, lanzador de WhatsApp, hoja de previsualización de solicitudes y ajustes de navegación y tarjetas del conductor. |
| 2026-10-22 | `6f23164` | Retiro de los respaldos legados de geocodificación y ruteo en Flutter; `PlaceLocator` queda con Google Maps y catálogo local. |
| 2026-10-22 | `2e00a80` | Retiro del módulo `geocode`, `shared/geocode` y `GET /geocode/search`; limpieza de configuración y regeneración de `docs/openapi.json`. |
| 2026-10-22 | `e29b0f7` | Migración `009_retirar_geocode_cache`: elimina `geocode_cache` y actualiza `purge_location_data()` para purgar solo `route_cache`. |
| 2026-10-22 | `00720af` | Reemplazo de las pruebas de geocodificación legadas por cobertura de Google Maps, catálogo local y widgets de dirección. |
| 2026-10-22 | `184a6f8` | ADR 0018 (Google Maps Platform en el cliente Flutter) y ADR 0019 (`flutter_map` + OpenStreetMap para renderizar). |
| 2026-10-22 | `c6f2350` | Alineación de README, arc42 02/08/10, `aspectos.md`, costos, resiliencia y `CHANGELOG-api.md` con Google Maps. |
| 2026-10-23 | `03e2a64` | ADR 0020 (decisión de datos más costosa de revertir), ampliación de arc42 08 y evidencia de invalidación de caché. |

### 1.2 Cierre de la revisión de arquitectura (25 de octubre)

**Documentación conciliada con la implementación**

- `docs/arc42/08_conceptos_transversales.md`: la caché de geocodificación del
  backend (`geocode_cache`, Photon/Nominatim, `GET /geocode/search`) se
  reemplazó por la caché en memoria del cliente (`PlaceLocator`, sin
  persistencia) y se documentó el `route_cache` vigente: TTL de 24 h, llave
  SHA-256 de coordenadas a 5 decimales, sin persistir ni servir resultados
  `degraded`, purga con `RETENTION_CACHE_DAYS`.
- `docs/arc42/05`: se agregó el módulo `matching` y se corrigió que los mapas
  los consume el cliente, mientras el backend consume OSRM y FCM.
- `docs/arc42/06`: el escenario de reserva se reescribió como solicitud →
  aceptación, con el descuento atómico por grupo.
- `docs/arc42/09`, `docs/arc42/11` y `docs/aspectos.md`: catálogo de ADR,
  riesgos y trazabilidad actualizados con el ADR 0021 y las pruebas nuevas.
- `compose.lab.yaml`: se retiraron `PHOTON_BASE_URL` y `GEOCODE_BBOX`, que ya
  no existen en `backend/app/core/config.py`.

**Despliegue Render → Dokploy**

- `README.md`: los pasos para recrear el entorno desde cero ahora describen
  Dokploy (servidor propio, rama `Changes`, `backend/Dockerfile`, dominio
  `routb.iscoutb.dev`, TLS, variables y verificación con `curl`).
- `render.yaml` se eliminó de la raíz, conforme a lo decidido en el ADR 0015.
  Las evidencias históricas de Render se conservan y el ADR 0015 ya documenta
  que su enlace a `render.yaml` queda roto por esa eliminación.

**Integridad de solicitudes y cupos**

- Migración `010_solicitud_activa_unica`: índice único parcial
  `uq_trip_requests_active_passenger` sobre `(trip_id, passenger_id)` con
  `status IN ('pending', 'accepted')`. Antes de crearlo concilia duplicados
  pendientes históricos (conserva la aceptada o la más antigua y cancela el
  resto).
- `create_request`: conserva el chequeo previo y traduce la violación del
  índice a `ActiveRequestAlreadyExistsError` (HTTP 400).
- `accept_request` y `reject_request`: si pierden la transición condicional,
  releen la solicitud y responden 404 si fue retirada o 409 si el estado no
  aplica; también se maneja el borrado concurrente después del commit para no
  terminar en un error 500.
- Nuevo ADR 0021 y evidencia detallada en
  [concurrencia-solicitudes-cupos.md](concurrencia-solicitudes-cupos.md).

### 1.3 Commit de cierre

| Dato | Valor |
|---|---|
| Hash | `48ba676216deda924cedd1f858e6fe1e1b5cb46f` |
| Fecha | 2026-10-25 12:49:32 -05:00 |
| Mensaje | `fix(requests): garantizar una solicitud activa por pasajero y viaje` |
| Alcance | 16 archivos: 5 de backend, 8 de arquitectura/evidencias y 3 de despliegue |

Archivos incluidos:

- **Backend:** `create_request.py`, `manage_request.py`, `models.py` de
  `requests`, migración `010_solicitud_activa_unica.py` y
  `test_requests_concurrency.py`.
- **Documentación:** ADR 0021, arc42 05/06/08/09/11, `aspectos.md` y
  `concurrencia-solicitudes-cupos.md`.
- **Despliegue:** `README.md`, `compose.lab.yaml` y eliminación de
  `render.yaml`.

## 2. Trazabilidad con la arquitectura y los aspectos

- **Aspecto 7 de `docs/aspectos.md`** (concurrencia y solicitudes verificadas):
  enlaza el ADR 0021, la prueba de concurrencia del flujo real y la evidencia
  de la corrida.
- **ADR 0018** reemplaza la parte de geocodificación del ADR 0010 y deja sin
  efecto la de geocodificación del ADR 0014; el routing del backend con OSRM se
  conserva.
- **ADR 0019** separa el renderizado del mapa (`flutter_map` + OpenStreetMap)
  del proveedor de datos (Google Maps).
- **ADR 0020** identifica el esquema de estados de solicitudes y el control
  atómico de cupos como la decisión de datos más costosa de revertir.
- **ADR 0021** formaliza la garantía de una sola solicitud activa por pasajero y
  viaje y la verificación de concurrencia del flujo crear → aceptar.
- **Regla vigente de solicitudes:** una solicitud activa por pasajero y viaje;
  sin tope entre viajes distintos; una aceptada por día y sentido (al aceptar se
  cancelan las demás pendientes de ese día y sentido); de 1 a 4 cupos por
  solicitud.

## 3. Verificación ejecutada

### 3.1 Backend

| Comando | Resultado |
|---|---|
| `pytest tests/test_requests_concurrency.py -q -s` | **5 passed** |
| `pytest -q` | **95 passed** en 26 min 52 s |

La suite completa incluye `test_cupos.py`, la prueba de contrato OpenAPI y el
ciclo de migraciones del fixture de pruebas, que aplicó y revirtió
`010_solicitud_activa_unica` sin errores.

Pruebas de concurrencia agregadas:

| Prueba | Escenario | Resultado |
|---|---|---|
| `test_aceptaciones_concurrentes_respetan_los_cupos` | 8 aceptaciones simultáneas sobre 4 cupos | 4 aceptadas, 4 conflictos, 0 cupos, sin negativos |
| `test_creaciones_simultaneas_del_mismo_pasajero_dejan_una_activa` | 8 creaciones simultáneas del mismo pasajero y viaje | 1 creada, 7 rechazadas, 1 activa en BD |
| `test_aceptar_y_retirar_simultaneamente_no_descuadran_los_cupos` | aceptar vs retirar | cupos completos, sin doble liberación ni 500 |
| `test_aceptar_y_rechazar_simultaneamente_dejan_estado_consistente` | aceptar vs rechazar | estado final y cupos coherentes |
| `test_grupo_sin_cupos_no_descuenta_parcialmente` | grupo sin cupos suficientes | 409 sin descuento parcial |

Nota de latencia: la base de pruebas local apunta a un pooler remoto de
Supabase, por lo que el p95 del flujo completo se reporta como informativo
(15,36 s en la corrida). El umbral duro p95 < 3,99 s se conserva en
`test_cupos.py`, que en CI usa PostgreSQL local (ADR 0003).

### 3.2 Frontend

| Comando | Resultado |
|---|---|
| `flutter analyze` | Sin hallazgos |
| `flutter test` | **138 tests passed** |
| `flutter build web` | Compilación correcta (`build/web`) |
| `dart format --output=none --set-exit-if-changed lib test` | Reporta 28 archivos con formato pendiente (deriva previa; no se aplicó para no introducir un diff ajeno) |

## 4. Decisiones y límites

- No se agregaron bloqueos de fila ni niveles de aislamiento nuevos: las
  transiciones y los cupos siguen resolviéndose con actualizaciones
  condicionales (ADR 0003) y el índice único parcial (ADR 0021).
- La migración `010` se validó en la base de pruebas; **no se aplicó a la base
  de desarrollo/producción de Supabase**. Antes de desplegar debe ejecutarse
  `alembic upgrade head` contra `DATABASE_URL`.
- No se reformateó el frontend: el chequeo de `dart format` muestra una deriva
  previa de 28 archivos que no forma parte de esta semana.
- No se ejecutó el despliegue ni el Quality Gate de Sonar en esta sesión.

## 5. Conclusión

La Semana 12 dejó la geocodificación y el ruteo del cliente consolidados con
Google Maps, el backend sin la caché de geocodificación retirada y la
documentación de arquitectura alineada con esa implementación. El cierre agregó
una garantía de integridad verificable en la base de datos para las solicitudes
activas, pruebas de concurrencia del flujo real crear → aceptar, y la guía de
despliegue actualizada a Dokploy. Backend y frontend quedaron en verde
(95 y 138 pruebas respectivamente), con los pendientes de despliegue y formato
declarados explícitamente. El commit de cierre es `48ba676`.

## 6. Registro de uso de IA

El detalle del uso de IA de la semana está en
[`docs/ia.md`](../ia.md#semana-12). En resumen: la IA se usó para analizar el
desfase entre documentación e implementación, proponer el mecanismo de
integridad y redactar la evidencia; las decisiones de arquitectura, esquema y
alcance fueron revisadas y aprobadas por el equipo, y cada cambio se verificó
con la suite correspondiente.
