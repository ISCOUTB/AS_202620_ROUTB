# ADR 0020: Identificacion de la decision de datos mas costosa de revertir

## Estado

Aceptado

## Contexto

Durante el ciclo de desarrollo de ROUTB se han tomado varias decisiones de datos
con impactos estructurales distintos. Para gestionar la deuda tecnica y el riesgo
arquitectonico es necesario identificar cual de estas decisiones tiene el mayor
costo de reversion, de modo que el equipo pueda priorizarla en cualquier
evaluacion de cambio arquitectonico futuro.

Las principales decisiones de datos tomadas en ROUTB son:

1. **Esquema de estados de solicitudes y cupos** — La tabla `trip_requests`
   modela el ciclo de vida de cada solicitud mediante los estados `pending`,
   `accepted`, `rejected`, `cancelled` y `expired`. La columna `available_seats`
   en `trips` es la fuente de verdad atomica para la disponibilidad de cupos
   ([ADR 0003](0003-control-atomico-de-cupos.md)).

2. **Monolito modular con base de datos compartida** — `requests` y `trips`
   comparten la misma instancia de PostgreSQL y ejecutan transacciones locales
   ACID para garantizar 0 % de sobreventa ([ADR 0001](0001-usar-monolito-modular.md),
   [ADR 0017](0017-decision-extraccion-modulo-requests.md)).

3. **Cache de geocodificacion en PostgreSQL** — La tabla `geocode_cache`
   almacena coordenadas normalizadas con TTL de 7 dias
   ([ADR 0010](0010-geocodificacion-y-cache.md)).

4. **Plataforma de persistencia: PostgreSQL en Supabase** — Todo el modelo
   relacional, migraciones y backups residen en una instancia gestionada de
   Supabase ([ADR 0006](0006-base-de-datos-supabase.md)).

## Criterios de evaluacion del costo de reversion

Para comparar el costo de revertir cada decision se usan cuatro criterios:

- **Alcance del cambio:** cuantas capas del sistema (modelo, migraciones,
  aplicacion, pruebas, documentacion) deben modificarse.
- **Riesgo en produccion:** probabilidad de perdida de datos o inconsistencia
  durante la transicion.
- **Tiempo estimado de reversion:** esfuerzo en dias/sprints para un equipo
  de 4 personas.
- **Dependencias transitivas:** cuantos otros ADR, modulos o contratos de API
  deben adaptarse.

## Tabla comparativa de costo de reversion

| Decision de datos | Alcance del cambio | Tiempo estimado | Riesgo en produccion | Dependencias transitivas |
|---|---|---|---|---|
| **Esquema de estados + cupos** (`trip_requests`, `available_seats`) | Todas las capas: migracion de datos en produccion, reescritura del mecanismo de control atomico (ADR 0003), nuevas pruebas de concurrencia, actualizacion de contratos de API y documentacion | > 2 sprints (aprox. 4 semanas) | **Muy alto** — una migracion fallida puede dejar solicitudes activas en estado indefinido o corromper el recuento de cupos | ADR 0001, 0003, 0007, 0017; `manage_request.py`, `request_seats.py`, `test_cupos.py`, contrato OpenAPI |
| **Monolito + BD compartida hacia microservicios** | Particion del esquema en dos bases de datos independientes, implementacion de Saga orquestada con compensaciones, nueva infraestructura de despliegue, trazabilidad distribuida | > 3 meses | **Muy alto** — ventana de inconsistencia durante la migracion; riesgo de sobreventa si la Saga falla antes de compensar | ADR 0001, 0003, 0004, 0015, 0017; todos los modulos del backend; CI/CD; Dokploy |
| **Plataforma PostgreSQL/Supabase** | Dump completo, transformacion del esquema para la nueva plataforma, actualizacion de `DATABASE_URL` y `DATABASE_URL_TEST`, validacion de backups | > 1 mes | **Alto** — riesgo de perdida de datos si el dump falla o hay incompatibilidades de version | ADR 0006, 0015; Dockerfile; render.yaml; CI/CD |
| **Cache `geocode_cache`** (TTL 7 dias) | Cambio de variable de entorno `RETENTION_CACHE_DAYS` + nueva migracion Alembic para limpiar entradas antiguas | < 1 dia | **Bajo** — el peor caso es latencia de respuesta hasta que expire el TTL anterior; no hay perdida de datos de negocio | ADR 0010, 0014 |

## Decision

La **decision de datos mas costosa de revertir** es la combinacion del **esquema
de estados de solicitudes (`trip_requests`) y el control atomico de cupos
(`available_seats` en `trips`)**, que opera sobre el **monolito con base de datos
compartida**.

Aunque la separacion del monolito tambien tendria un costo muy alto, ese es un
cambio arquitectonico de despliegue. La decision de *datos* mas costosa es el
esquema de estados + cupos porque:

1. **Dependencia de consistencia ACID:** El mecanismo de `UPDATE ... WHERE
   status='pending' AND ...` depende de que ambas tablas esten en la misma
   transaccion. Mover o redisenar ese esquema exige reemplazar esta garantia
   con algo equivalente (Saga, 2PC), que multiplica la complejidad.

2. **Datos historicos con semantica de estado:** Las solicitudes en estados
   `accepted`, `cancelled` y `expired` representan historial real de viajes.
   Una migracion de estados mal disenada puede alterar retroactivamente ese
   historial, afectando auditorias y reportes.

3. **Pruebas de concurrencia criticas:** `backend/tests/test_cupos.py` verifica
   la invariante de 0 % de sobreventa. Cualquier cambio en el esquema debe
   mantener pasando esa prueba; un rediseno sin cobertura equivalente
   introduciria una regresion invisible.

4. **Costo comparativo superior:** A diferencia de la cache de geocodificacion
   (reversible en horas sin riesgo de negocio), o del cambio de plataforma
   PostgreSQL (costoso pero no afecta logica de dominio), el esquema de estados
   toca simultaneamente la logica de negocio, la integridad de datos historicos
   y las garantias de concurrencia.

## Consecuencias

### Positivas

- El equipo tiene claridad sobre que cambios en el modelo de datos requieren
  una revision formal (nuevo ADR, pruebas de migracion, ventana de mantenimiento)
  antes de aplicarse.
- Se refuerza la justificacion del ADR 0017 (no extraer `requests` a
  microservicio): la extraccion haria que esta decision —ya la mas costosa de
  revertir— se volviera aun mas costosa al anadir complejidad distribuida.

### Negativas / Riesgos asumidos

- La dependencia entre el esquema de estados y el control atomico de cupos
  significa que **cualquier cambio futuro** en los estados de solicitud debe
  acompanarsse de una migracion Alembic revisada manualmente, pruebas de
  concurrencia actualizadas y un ADR nuevo que justifique el cambio.
- No hay mecanismo de rollback automatico de datos ya en produccion; la unica
  estrategia de recuperacion es el backup de Supabase previo a la migracion.

## Trazabilidad

| Criterio / Artefacto | Referencia |
|---|---|
| Control atomico de cupos | [ADR 0003](0003-control-atomico-de-cupos.md) |
| Monolito modular | [ADR 0001](0001-usar-monolito-modular.md) |
| Decision de no extraer `requests` | [ADR 0017](0017-decision-extraccion-modulo-requests.md) |
| Plataforma de base de datos | [ADR 0006](0006-base-de-datos-supabase.md) |
| Cache de geocodificacion | [ADR 0010](0010-geocodificacion-y-cache.md) |
| Implementacion del mecanismo critico | `backend/app/modules/requests/application/manage_request.py` |
| Prueba de concurrencia de cupos | `backend/tests/test_cupos.py` |
| Estrategia integrada de consistencia | `docs/arc42/08_conceptos_transversales.md` seccion 8.7 |