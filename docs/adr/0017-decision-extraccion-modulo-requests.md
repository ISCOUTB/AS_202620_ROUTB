# ADR 0017: Decisión sobre la extracción del módulo de solicitudes y reservas (requests) a microservicio independiente

## Estado

Aceptado

## Contexto

El backend de ROUTB fue diseñado originalmente bajo un estilo de **monolito modular** ([ADR 0001](0001-usar-monolito-modular.md)), donde cada dominio funcional (`auth`, `users`, `trips`, `requests`, `notifications`) está organizado en módulos con separación interna por capas ([ADR 0002](0002-usar-arquitectura-interna-por-capas.md)), pero desplegados conjuntamente en un único proceso FastAPI y compartiendo una misma base de datos PostgreSQL ([ADR 0006](0006-base-de-datos-supabase.md)).

A medida que el flujo de reservas y solicitudes grupales evolucionó ([ADR 0007](0007-reserva-grupal-de-cupos.md)), surgió el interrogante arquitectónico de si el módulo de gestión de solicitudes (`requests`) —o alternativamente `trips`— debería extraerse del monolito y convertirse en un microservicio autónomo e independiente, con su propio ciclo de despliegue, base de datos dedicada y comunicación vía red (HTTP/gRPC/mensajería).

## Criterios de decisión

Para evaluar objetivamente la extracción o permanencia del módulo, el equipo definió cuatro criterios técnicos y operativos reales:

1. **Tamaño y capacidad del equipo:** El equipo está conformado por 4 estudiantes universitarios. Administrar múltiples repositorios, pipelines de CI/CD independientes, versionado de contratos distribuidos y observabilidad distribuida añade una carga cognitiva y operativa desproporcionada.
2. **Acoplamiento de datos y consistencia transaccional:** La gestión de solicitudes (`requests`) y la disponibilidad de cupos (`trips.available_seats`) requieren consistencia transaccional estricta (ACID) para impedir la sobreventa bajo concurrencia ([ADR 0003](0003-control-atomico-de-cupos.md)). En el monolito modular, esto se resuelve con transacciones de base de datos locales y actualizaciones condicionales en SQL (`UPDATE ... WHERE available_seats >= N`). Separar los módulos exigiría transacciones distribuidas (Saga orquestada o 2PC), mecanismos de compensación asíncronos y eventual consistencia, aumentando drásticamente la probabilidad de carreras y sobreventa.
3. **Frecuencia de cambio y ciclo de vida:** Ambos módulos (`trips` y `requests`) evolucionan de forma coordinada dentro del mismo sprint académico; no existe un equipo independiente ni un ritmo de despliegue divergente que justifique pipelines y releases separados.
4. **Costo operativo e infraestructura:** El proyecto opera bajo una restricción mandataria de costo cero ($0.00 USD) sin tarjetas bancarias ([ADR 0005](0005-render-plataforma-de-despliegue.md) y [ADR 0015](0015-dokploy-plataforma-de-despliegue.md)). Alojar dos o más servicios independientes superaría la cuota de recursos gratuitos o duplicaría la sobrecarga de mantenimiento operativo y monitoreo.

## Opciones evaluadas

### Opción 1: Extraer el módulo `requests` a un microservicio independiente

Separar el código de `backend/app/modules/requests/` en un nuevo repositorio o contenedor autónomo, con su propia API REST pública y base de datos independiente, comunicándose con `trips` mediante llamadas HTTP o colas de mensajería.

- **Ventajas:**
  - Despliegue y escalado independiente: Si el volumen de solicitudes por segundo supera la consulta de viajes, el servicio de solicitudes podría escalar horizontalmente por separado.
  - Aislamiento de fallos en runtime: Un fallo crítico de memoria o bloqueo en `requests` no tumbaría el proceso de consulta de viajes o autenticación.
  - Autonomía estricta de esquema: Imposibilidad física de realizar acoplamientos a nivel de base de datos (claves foráneas directas o consultas cruzadas).
- **Costos y desventajas:**
  - Pérdida de atomicidad ACID: La aceptación de una solicitud y el decremento de cupos ya no pueden ejecutarse en una transacción local única; requiere implementar el patrón Saga con reversión compensatoria.
  - Mayor latencia de red: Cada operación de solicitud exigiría múltiples saltos de red (*network hops*) HTTP síncronos entre microservicios, aumentando el p95 más allá del umbral de calidad fijado en 3.99 s.
  - Mayor costo operativo y complejidad: Superaría los límites de despliegue ligero y requeriría orquestación de múltiples contenedores.
  - Mayor complejidad de observabilidad: Exigiría trazabilidad distribuida (Correlation IDs, OpenTelemetry) para depurar errores entre servicios.

### Opción 2: No extraer (Mantener `requests` dentro del monolito modular) — *Seleccionada*

Conservar `requests` dentro del monolito modular backend de ROUTB, garantizando límites modulares estrictos mediante contratos de interfaz pública en `trips.application` y `requests.application`, sin compartir mutaciones directas de ORM.

- **Ventajas:**
  - Consistencia atómica garantizada: Capacidad de ejecutar transacciones ACID locales y actualizaciones condicionales en PostgreSQL para asegurar 0 % de sobreventa en cupos concurrentes.
  - Despliegue simple y costo cero ($0.00 USD): Un solo contenedor backend y una única base de datos, cumpliendo con la restricción presupuestaria.
  - Baja sobrecarga para un equipo de 4 personas: Un único repositorio, un solo pipeline en GitHub Actions y una suite de pruebas unificada.
  - Rendimiento óptimo: Invocaciones en memoria entre módulos sin latencia de red adicional ni riesgo de fallo en tránsito entre componentes backend.
- **Costos y desventajas:**
  - Acoplamiento en tiempo de ejecución: Un fallo general del contenedor afecta a todos los módulos por igual.
  - Requiere disciplina de equipo: Obliga a realizar auditorías continuas de erosión modular para evitar que `requests` importe modelos o tablas de `trips` directamente.

## Decisión

El equipo decide **NO EXTRAER** el módulo `requests` (ni ningún otro módulo del backend) a un microservicio independiente. Se mantiene la arquitectura de **monolito modular** ([ADR 0001](0001-usar-monolito-modular.md)), reforzando las fronteras entre módulos mediante capas de aplicación públicas y auditorías periódicas de acoplamiento.

Esta decisión se fundamenta estrictamente en la necesidad de preservar la consistencia atómica de cupos sin la complejidad de Sagas distribuidas, la capacidad operativa de un equipo de 4 desarrolladores y la viabilidad técnica dentro de la infraestructura del proyecto.

## Consecuencias

### Positivas

1. **Garantía de no sobreventa:** Las reservas individuales y grupales conservan atomicidad estricta en base de datos bajo transacciones PostgreSQL locales.
2. **Operatividad sostenible:** Se preserva el costo $0.00 USD y la simplicidad del pipeline de integración continua sin dispersión en múltiples repositorios o despliegues.
3. **Mantenimiento del umbral de latencia:** Las llamadas entre casos de uso se realizan en memoria local (microsegundos), evitando la degradación del tiempo de respuesta (p95 < 3.99 s).

### Negativas / Riesgos asumidos

1. **Riesgo de indisponibilidad compartida:** Si el backend entra en suspensión o reinicio, tanto la búsqueda de viajes como la gestión de solicitudes experimentan indisponibilidad transitoria. Este riesgo se mitiga en el cliente con timeouts configurados y reintentos manuales.
2. **Vigilancia de erosión:** El equipo debe vigilar que la interacción entre `requests` y `trips` se realice exclusivamente a través de las funciones públicas de aplicación (`reserve_request_seats`, `release_request_seats`, `get_trip_request_context`) sin saltarse capas ni consultar tablas ajenas.

## Trazabilidad

| Criterio / Artefacto | Referencia |
|---|---|
| Estilo base | [ADR 0001: Monolito modular](0001-usar-monolito-modular.md) |
| Control atómico de cupos | [ADR 0003: Control atómico de cupos](0003-control-atomico-de-cupos.md) |
| Integración síncrona | [ADR 0004: Integración síncrona REST/JSON](0004-integracion-sincrona-rest.md) |
| Infraestructura y despliegue | [ADR 0005](0005-render-plataforma-de-despliegue.md), [ADR 0006](0006-base-de-datos-supabase.md) y [ADR 0015](0015-dokploy-plataforma-de-despliegue.md) |
| Reserva grupal de cupos | [ADR 0007: Solicitud grupal de cupos](0007-reserva-grupal-de-cupos.md) |
| Código de coordinación | `backend/app/modules/requests/application/manage_request.py` |
| Vista de contenedores | [C4 Nivel 2](../c4/context.md) |
