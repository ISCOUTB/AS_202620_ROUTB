# Documentación del avance — Semana 10 (segundo corte)

## Resumen ejecutivo

Durante la Semana 10 el equipo cerró el segundo corte sobre una porción ya implementada: la reserva concurrente de cupos y el flujo de solicitudes con paradas, vencimiento y push en ROUTB. El escenario del corte es propio del equipo: las reservas concurrentes no sobrevenden (cero aceptaciones de más) y el flujo REST se mantiene en verde aunque fallen FCM u OSRM. Como escenario secundario se conserva el rendimiento de `GET /trips/` con el umbral ya publicado (p95 < 3,99 s).

La porción se validó con la suite backend completa en verde (79 passed, incluyendo cupos, asignación, paradas, push con mocks, vencimiento y contrato OpenAPI), con la suite Flutter en verde (100 passed, `flutter analyze` limpio, `flutter build web` OK), con medición de rendimiento local, con auditoría de erosión modular y con barrido de credenciales. La decisión de concurrencia sigue documentada en los ADR 0003 y 0007, extendida por los ADR 0012 (matching y paradas) y 0013 (push FCM), y se mantuvo fuera del alcance la integración de un componente generativo en runtime.

## 1. Porción entregada

- **Funcionalidad:** reservas concurrentes sin sobreventa y solicitudes con paradas, asignación, vencimiento y push en ROUTB.
- **Regla de negocio aprobada:** un pasajero puede reservar de 1 a 4 personas en total; dos aceptaciones simultáneas sobre los mismos cupos producen una sola aceptación; al aceptar, las demás pendientes del mismo pasajero, día y sentido quedan canceladas; una solicitud vencida no se puede aceptar (409 `request_expired`).
- **Comportamiento:** los viajes con `direction` exigen paradas cuya suma iguala `seat_count` (una sola en `to_campus`); un fallo de FCM no revierte ni bloquea el flujo REST; el pasajero ve su viaje activo en el buscador aunque el listado público ya no lo traiga.
- **Implementación técnica:** la disponibilidad se controla de forma atómica mediante operaciones públicas del módulo `trips`; la validación de área usa un único parser de `GEOCODE_BBOX` en matching y solicitudes.
- **Compatibilidad:** el contrato OpenAPI publicado en el repo es 0.6.0 con 20 rutas; el despliegue en Render sirve 0.4.0 con 15 rutas, por lo que el redespliegue (merge a `master`) queda como paso pendiente del equipo.

## 2. Evidencia de trazabilidad con la arquitectura y el aspecto

- **Fila de `docs/aspectos.md`:** la concurrencia y las solicitudes verificadas del segundo corte quedan registradas como aspecto 7, enlazado con sus ADR, con los módulos dueños (`trips`, `requests`, `notifications`) y con la evidencia de pruebas y medición que lo respalda.
- **ADR 0003 — Control atómico de cupos:** sirve como base técnica para la validación de concurrencia y sobreventa.
- **ADR 0007 — Reserva grupal de cupos:** documenta la regla de negocio de 1 a 4 cupos y la decisión de grupo completo.
- **ADR 0012 — Sugerencias y paradas:** documenta matching de solo lectura, score y orden de paradas a lo largo de la ruta.
- **ADR 0013 — Push FCM:** documenta FCM como aviso que complementa la verdad REST, con borrado automático de tokens inválidos.
- **Arquitectura:** el buscador del pasajero conserva la tarjeta de viaje activo y la navegación inferior no se desborda en móvil estrecho; el contrato y la implementación coinciden exactamente (título, versión, 20 rutas).

## 3. Prueba de defecto y validación funcional

La evidencia incorpora pruebas que cubren el defecto funcional perseguido y sus efectos de negocio.

- **Casos cubiertos:**
  - reservas concurrentes que no sobrevenden (`test_cupos.py`, aceptaciones grupales concurrentes),
  - aceptar cancela pendientes del mismo día y sentido y no toca las de otra fecha o sentido,
  - viajes legados sin `direction` conservan el comportamiento anterior,
  - paradas con suma distinta de `seat_count` y más de una parada en `to_campus` responden 422,
  - solicitud vencida que no se puede aceptar (409 `request_expired`),
  - fallo de FCM que no revierte la transacción REST y token inválido que se elimina,
  - contrato OpenAPI que detecta cambios incompatibles.
- **Objetivo de la prueba crítica:** garantizar que dos aceptaciones simultáneas no puedan reservar más cupos de los disponibles.
- **Validación del contrato:** el contrato versionado coincide con la app (OpenAPI 3.1.0, `ROUTB API` 0.6.0, 20 rutas sin faltantes ni sobrantes).
- **Resultado:** suite backend 79 passed en corrida secuencial; suite Flutter 100 passed con `flutter analyze` limpio y `flutter build web` OK; ciclo `alembic upgrade/downgrade/upgrade` verificado con `007_add_device_tokens` en `head`.

La evidencia de regresión demuestra que la porción cumple el alcance definido y que el sistema conserva el comportamiento esperado ante condiciones concurrentes y de capacidad reducida.

## 4. Medición del escenario asociado

Se midió el rendimiento del listado de viajes y se comparó con la línea base. La medición confirma que el escenario mantiene un tiempo de respuesta dentro del umbral de calidad del proyecto.

- **Criterio de validación:** el 95 % de las respuestas a `GET /trips/` (p95) debe estar por debajo de 3,99 s, y la concurrencia debe producir cero sobreventas.
- **Resultado local (11 de octubre de 2026):** `GET /trips/` local caliente, N=100, p95=1,1860 s frente al umbral de 3,99 s → **CUMPLE**; concurrencia de cupos y aceptaciones grupales concurrentes → **cero sobreventas**.
- **Comparación con la línea base:** la base S9 es externa sobre producción (p95 697,82 ms) y la S10 es local contra la base de pruebas; no son comparables de forma directa ni la diferencia es atribuible al cambio funcional. Ambas están por debajo del umbral. La medición interna oficial con logs de Render sigue pendiente del redespliegue.

## 5. Registro de uso de IA

El extracto de `docs/ia.md` (entrada Semana 10) deja claro que la IA se usó como apoyo durante la estabilización, pero no como autoridad técnica ni como ejecutora automática de decisiones de negocio. La cadena de evidencias separa claramente:

- **Lo aceptado:** las correcciones mínimas con causa identificada (paradas en pruebas de asignación, hora futura en pruebas de viajes, tarjeta de viaje activo, formato de BBOX compartido).
- **Lo corregido:** la hipótesis inicial sobre tablas ausentes apuntaba al código; la evidencia de corridas aisladas mostró contaminación entre sesiones concurrentes, por lo que la corrección fue el procedimiento (una sola suite a la vez).
- **Lo rechazado:** reformatear todo el repositorio con el SDK nuevo, regenerar el contrato sin cambios y declarar la fase como completada sin prueba en dispositivo real.

En particular:

- la regla de cupos y la atomicidad fueron definidas por el equipo y validadas por la arquitectura,
- cada cambio se verificó ejecutando la prueba afectada antes de darlo por bueno,
- la IA no toma decisiones de negocio ni se integra al runtime en producción.

## 6. Auditoría de erosión modular

La auditoría de erosión modular verificó que el diseño del sistema no se degradara durante la porción.

### Hallazgos revisados y corregidos

- `requests` consume los contratos públicos de `trips.application` para leer contexto y aplicar reserva/liberación atómicas; no muta el ORM de otro módulo.
- La validación de área geográfica usa el mismo parser en matching y en solicitudes, en vez de dos implementaciones divergentes.
- Se eliminaron importaciones que quedaron sin uso tras retirar el chequeo de consentimiento del pasajero en la creación de solicitudes.
- Las pantallas no hacen llamadas HTTP ni acceden a almacenamiento: la API pasa por repositorios y el estilo sale de la paleta.
- Los routers traducen HTTP y delegan; sin reglas de negocio ni SQL concatenado con entrada de usuario.

### Límite aceptado

La entidad `TripRequest` conserva una relación de navegación con `Trip` para composiciones de lectura, pero la escritura de disponibilidad se hace desde el módulo dueño (`trips`), no desde `requests`. La creación de solicitudes ya no exige consentimiento de ubicación del pasajero; el consentimiento se exige donde hay coordenadas del conductor. Esto permite mantener la separación de responsabilidades sin eliminar la capacidad operativa del sistema.

## 7. Verificación de dependencias, credenciales y alcance

Se verificó que la porción no introdujo dependencias ajenas al alcance del proyecto ni elementos críticos de configuración.

- **Dependencias:** no se añadieron paquetes nuevos; la solución reutiliza el stack ya definido (`requirements.txt` sigue fijado con hashes). El pipeline incluye el escaneo de SonarQube Cloud y usa el secreto `SONAR_TOKEN`; el resultado del Quality Gate depende de la corrida de CI.
- **Credenciales:** barrido de patrones de secretos en el código y de archivos `.env`/`google-services.json` en el historial: los `.env` están ignorados y nunca se versionaron; solo aparece el placeholder documentado de `.env.example`. Limpio.
- **Despliegue:** `GET /health` en Render respondió `{"status":"ok"}` en la comprobación documentada (tras arranque en frío; se observó un 503 transitorio propio del plan gratuito). En ese levantamiento, la versión publicada era 0.4.0 con 15 rutas frente al contrato 0.6.0 con 20 rutas del repo. La configuración posterior de auto despliegue desde `Changes` tras checks se registra en la sección 10; no se da por verificado un nuevo despliegue sin comprobar el servicio.
- **Alcance:** se confirma la decisión de no incorporar IA generativa en runtime (ADR 0008) y no se creó ningún flujo de extracción de datos de acompañantes ni de cuentas adicionales.
- **Equipo:** 4 autores con aportes en el historial (MKeinerrr con dos correos, junior14700, juliandmanjarrez-tech, diegobrr999-commits).

## 8. Decisión sobre el componente generativo

Se confirma no incorporar un componente generativo a ROUTB para esta porción ni como parte del runtime del producto (ADR 0008). La razón principal es que el problema de negocio no requiere inferencia generativa en tiempo de ejecución, y la decisión fue reforzada por la necesidad de mantener la arquitectura del sistema simple, trazable y controlada.

La IA se utilizó únicamente como apoyo para análisis, documentación, revisión y exploración de alternativas; las decisiones finales de alcance y arquitectura fueron del equipo y fueron validadas con pruebas, medición y auditoría.

## 9. Conclusión

La Semana 10 cerró el segundo corte con evidencia completa: escenario propio declarado, decisión arquitectónica, validación funcional en verde en backend y Flutter, medición dentro del umbral, revisión modular, barrido de credenciales y documentación de uso de IA. El conjunto confirma que la reserva concurrente no sobrevende, que las solicitudes con paradas y vencimiento se comportan según el contrato y que no hay regresiones relevantes en disponibilidad ni operatividad.

Al cierre de la medición original quedaban pendientes el redespliegue de producción, SonarCloud, la prueba push con la app cerrada en dispositivo Android real y el ensayo en staging. La sección 10 registra los cambios posteriores de routing, CI y configuración Render; las verificaciones externas y en dispositivo continúan pendientes.

## 10. Continuidad: resiliencia del cálculo de rutas

Se incorporó una corrección adicional al servicio de routing: el TTL de
`route_cache` usa un intervalo PostgreSQL parametrizado, el timeout de OSRM se
configura con `ROUTING_TIMEOUT_SECONDS` (3.0 s por defecto), y los resultados
`degraded` no se guardan ni se sirven desde caché. El detalle de la decisión y
las pruebas está en el [ADR 0014](../adr/0014-fallback-geocode-cache.md) y en la
[evidencia del corte 2](corte2-fallo-medicion.md).

El workflow en `Changes` ejecuta la suite backend, el contrato OpenAPI por
separado y SonarQube Cloud con `SONAR_TOKEN`; Render declara auto despliegue de
`Changes` tras los checks. En la primera corrida de `64986a2`, backend y OpenAPI
pasaron; Sonar terminó con error del scanner y bloqueó el despliegue. La medición
pasó el umbral en ambos escenarios (`p95 < 3.99 s`), aunque el p95 exacto no fue
accesible desde la consulta pública. El redespliegue real y las pruebas en
dispositivo siguen pendientes de confirmación.
