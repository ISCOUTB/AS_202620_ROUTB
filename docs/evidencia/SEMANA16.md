# ROUTB · Evidencias del cierre de semana 16

Revisión del 22 de noviembre de 2026, hora de Colombia. El estado funcional de referencia es [master, 9287f8a](https://github.com/ISCOUTB/AS_202620_ROUTB/commit/9287f8a1c74e8b27926aee9b5793b99b900a9912), integrado a las 22:39:15 mediante el [PR 84](https://github.com/ISCOUTB/AS_202620_ROUTB/pull/84). Comparte el árbol Git `82d8d60` con la revisión inspeccionada de `Changes` (`3c98a1e`). La fecha límite académica queda por contrastar con la convocatoria. Este índice reúne las pruebas del producto y enlaza los registros originales de [semanas anteriores](../evidencia/).

## Sistema desplegado

Comprobaciones públicas entre las 22:40 y las 22:42. Los tiempos corresponden a una petición por ruta. El SHA exacto de la imagen en producción requiere el registro de Dokploy.

| Operación | Resultado observado |
|---|---|
| [Abrir el frontend](https://approutb.iscoutb.dev/) y cargar [el programa Flutter](https://approutb.iscoutb.dev/main.dart.js) | 200 HTML en 0,391 s y 200 JavaScript en 1,093 s. |
| [Consultar salud de la API](https://routb.iscoutb.dev/health) | 200 JSON en 0,493 s. |
| [Consultar viajes](https://routb.iscoutb.dev/trips/) | 200 JSON en 1,117 s. En la consulta de contenido el listado estaba vacío. |
| GET `/requests/me` sin token | 401 en 0,301 s. |
| GET `/ruta-inexistente-s16` | 404 en 0,295 s. |
| POST `/auth/login` con JSON `{}` | 422. FastAPI identificó los dos campos obligatorios ausentes, `phone` y `password`. |

**Flujo con datos de prueba.** El [job de backend del cierre](https://github.com/ISCOUTB/AS_202620_ROUTB/actions/runs/45107254308/job/137471256098) ejecutó la suite sobre PostgreSQL de pruebas. El caso `test_reserva_grupal_de_cuatro_y_cancelacion_libera_todos_los_cupos` recorre solicitud, aceptación y devolución de los cuatro cupos. Las carreras de aceptación comprueban el saldo y la ausencia de reservas parciales. El [job Flutter](https://github.com/ISCOUTB/AS_202620_ROUTB/actions/runs/45107254308/job/137471255808) cubre navegación y widgets. La aceptación de extremo a extremo con dos cuentas y un viaje en producción queda por acreditar en la demostración. [Flujo de solicitudes](../../backend/tests/test_requests_flow.py) · [Concurrencia](../../backend/tests/test_requests_concurrency.py) · [Pantallas de ambos roles](../../frontend/test/mode_tabs_test.dart)

## Alcance y decisiones

| Compromiso del segundo corte | Entrega comprobable |
|---|---|
| Reservar entre uno y cuatro cupos, evitar sobreventa y cancelar solicitudes incompatibles | La aceptación delega el descuento atómico al dueño del viaje. La suite cubre creación duplicada, operaciones concurrentes y cancelación de pendientes por día y sentido. [Gestión de solicitudes](../../backend/app/modules/requests/application/manage_request.py) · [Operaciones de cupos](../../backend/app/modules/trips/application/request_seats.py) · [Asignación](../../backend/tests/test_requests_assignment.py) |
| Solicitudes con paradas y vencimiento | La suma y sentido de las paradas se validan al solicitar. Una aceptación vencida se rechaza. [Pruebas de paradas](../../backend/tests/test_request_stops.py) · [Casos de vencimiento](../../backend/tests/test_requests_flow.py) |
| Mantener la operación REST ante fallos de FCM y degradar el cálculo ante fallos de OSRM | Los avisos se despachan después del commit. El servicio de rutas puede devolver una aproximación. [Pruebas de push](../../backend/tests/test_push.py) · [Pruebas de routing](../../backend/tests/test_routing.py) · [Medición con fallo](../evidencia/corte2-fallo-medicion.md) |

La referencia S10 es el commit de integración `adde017` del 12 de octubre. Entre ese árbol y el final cambiaron 374 archivos, con 44.004 inserciones y 6.298 eliminaciones. La evolución incluye edición de cuenta, datos del vehículo, cambio de modalidad y el contenedor de Flutter Web. Las exclusiones explícitas incluyen cuentas de acompañantes e IA generativa en ejecución. Continúan como deuda la entrega durable de avisos ante reinicio y los reintentos automáticos documentados en resiliencia. [Alcance S10](../evidencia/SEMANA10.md) · [Comparación S10–S16](https://github.com/ISCOUTB/AS_202620_ROUTB/compare/adde017b72d73f210eef6cb48d97cdf1687f5141...9287f8a1c74e8b27926aee9b5793b99b900a9912) · [Resiliencia](../evidencia/resiliencia-y-modos-de-fallo.md)

**Recorrido por los 29 ADR.** Los ADR 0001–0008 cubren límites del monolito, cupos y despliegue inicial. Del 0009 al 0016 se incorporan geodatos, matching, notificaciones y Dokploy. Del 0017 al 0025 se precisan propiedad, integridad, seguridad y despacho asíncrono. Del 0026 al 0029 se documentan vehículo, permisos, eliminación de cuenta y modalidades. Un reemplazo verificable es Render → Dokploy: el ADR inicial enlaza expresamente su sustituto y la evidencia registra la operación del servicio. [Catálogo ordenado](../adr/) · [ADR 0005](../adr/0005-render-plataforma-de-despliegue.md) · [ADR 0015](../adr/0015-dokploy-plataforma-de-despliegue.md) · [Verificación del despliegue](../evidencia/despliegue-dokploy.md)

## Calidad, seguridad y trazabilidad

| Criterio | Resultado y ubicación de la prueba |
|---|---|
| Consistencia de cupos | Línea base histórica: 0/20 intentos procesados por ausencia de la ruta. Después: 20/20 procesados, exactamente 4 aceptados sobre 4 cupos y saldo 0. El flujo vigente se verifica con las pruebas de solicitudes del cierre. [Escenario y procedimiento](../arc42/10_requisitos_de_calidad.md#escenario-de-consistencia-de-cupos) · [Invariantes actuales](../evidencia/concurrencia-solicitudes-cupos.md) |
| Rendimiento | Umbral p95 < 3.990 ms. S14 midió 3 rondas de 100 consultas: peor p95 de 631,76 ms en Dokploy con listado vacío y 2.564,52 ms en local con cinco viajes. Son mediciones históricas con cargas diferentes. [Procedimiento y resultados crudos](../evidencia/medicion-semana14.md) · [Script](../../scripts/medir_rendimiento.py) |
| Fallos externos y seguridad | Con OSRM simulado, N=50 por escenario, el p95 pasó de 1,6368 s a 2,7047 s con fallo, con cero HTTP 500 en ambos. La suite comprueba permisos y los fallos de proveedores. CI incluye auditoría de dependencias. Persisten riesgos de respaldo y entrega de notificaciones. [Medición](../evidencia/corte2-fallo-medicion.md) · [STRIDE](../evidencia/SEMANA13.md) · [Riesgos](../arc42/11_riesgos_y_deuda_tecnica.md) · [Auditoría CI](https://github.com/ISCOUTB/AS_202620_ROUTB/actions/runs/45107254308/job/137471255981) |
| arc42, C4 y contrato | Están las 12 secciones, incluido el glosario. El barrido de marcadores literales de plantilla no encontró pendientes de ese tipo. Los tres niveles C4 están en un archivo. Hay desfases: la vista de despliegue describe el cliente móvil y omite Nginx web; el nivel 3 dibuja reputación/calificaciones, sin módulo dedicado en la entrega. El OpenAPI publicado coincidió con el JSON del repositorio, versión 0.12.0 y 23 rutas. [arc42](../arc42/) · [Glosario](../arc42/12_glosario.md) · [C4](../c4/context.md) · [Módulos reales](../../backend/app/modules/) · [Despliegue web](../../frontend/Dockerfile) · [Contrato versionado](../openapi.json) · [Contrato público](https://routb.iscoutb.dev/openapi.json) |
| Validación automática | CI ejecuta el contrato y cuatro pruebas de límites entre módulos, incluida la prohibición de mutar viajes desde solicitudes. La revisión de enlaces y diagramas fue manual en este corte. En la corrida histórica enlazada, el job denominado SonarCloud ejecutó un `echo`; su resultado verde por sí solo no acredita un Quality Gate. [Workflow](../../.github/workflows/ci.yml) · [Contrato](../../backend/tests/test_openapi_contract.py) · [Límites modulares](../../backend/tests/test_module_boundaries.py) · [Run de master](https://github.com/ISCOUTB/AS_202620_ROUTB/actions/runs/45107254308) |

**Matriz de aspectos.** Se recorrieron las **10/10 filas** y se comprobó la existencia de los destinos locales de sus 123 enlaces, incluidas referencias repetidas. Se contrastaron los cuatro fragmentos de enlace distintos con sus encabezados. Algunas filas remiten a directorios o a mediciones históricas. Tres recorridos completos permiten reproducir la lectura de requisito → decisión → implementación → prueba → resultado. [Matriz original con contextos y C4](../aspectos.md)

| Fila y requisito | Decisión | Implementación | Verificación |
|---|---|---|---|
| 6 · Reservar el grupo completo | [ADR 0007](../adr/0007-reserva-grupal-de-cupos.md) | [Solicitudes](../../backend/app/modules/requests/) y [cupos](../../backend/app/modules/trips/application/request_seats.py) | [Prueba del grupo de cuatro](../../backend/tests/test_requests_flow.py) · [Resultado registrado](../evidencia/prueba-reserva-grupal-semana9.md) |
| 7 · Evitar sobreventa entre aceptaciones simultáneas | [ADR 0021](../adr/0021-integridad-solicitudes-y-concurrencia.md) | [Aceptación y retiro](../../backend/app/modules/requests/application/manage_request.py) | [Pruebas de carrera](../../backend/tests/test_requests_concurrency.py) · [Resultados e invariantes](../evidencia/concurrencia-solicitudes-cupos.md) |
| 9 · Degradar ante timeout de routing | [ADR 0014](../adr/0014-fallback-geocode-cache.md) | [Servicio de rutas](../../backend/app/shared/routing/service.py) | [Pruebas de recuperación y caché](../../backend/tests/test_routing.py) · [Resultados con y sin fallo](../evidencia/corte2-fallo-medicion.md) |

## Colaboración y sustentación

Los cuatro nombres y las cuatro cuentas figuran en el [registro del curso](https://github.com/ISCOUTB/AS_202620_feedback/blob/master/EQUIPOS.md). Los conteos son commits por autor y mes de autoría hasta `3c98a1e`, incluidos merges y excluidos bots. La columna final identifica una responsabilidad ejercida mediante un cambio concreto. [Equipo del proyecto](../../README.md#equipo-de-desarrollo)

| Integrante y cuenta | Ago | Sep | Oct | Nov | Aporte verificable |
|---|---:|---:|---:|---:|---|
| Diego Baron · diegobrr999-commits | 8 | 3 | 0 | 0 | [Estrategia de solución](https://github.com/ISCOUTB/AS_202620_ROUTB/commit/467a1b6) |
| Julian Manjarrez · juliandmanjarrez-tech | 6 | 6 | 1 | 0 | [Pantallas de pasajero y conductor](https://github.com/ISCOUTB/AS_202620_ROUTB/commit/5363d07) |
| Junior Orozco · junior14700 | 23 | 10 | 15 | 0 | [Prototipo de mensajería asíncrona](https://github.com/ISCOUTB/AS_202620_ROUTB/commit/4c906eb) |
| Keiner Mendivil · MKeinerrr | 84 | 120 | 80 | 58 | [Despliegue y presentación web](https://github.com/ISCOUTB/AS_202620_ROUTB/commit/ad73cd4) |

**Revisión cruzada parcialmente acreditada.** En el PR 52 Junior intervino sobre la resolución de conflictos. Los 12 comentarios de revisión en línea devueltos por GitHub fueron de un bot; las revisiones consultadas de los PR 52, 82 y 84 tampoco acreditan comentarios técnicos de fondo entre dos integrantes. La actividad de autoría sí queda identificada. [Intervención de Junior](https://github.com/ISCOUTB/AS_202620_ROUTB/pull/52#issuecomment-6367470104) · [Comentarios de revisión](https://api.github.com/repos/ISCOUTB/AS_202620_ROUTB/pulls/comments?per_page=100)
