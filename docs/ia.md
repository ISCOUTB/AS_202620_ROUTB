# Uso de Inteligencia Artificial

## Propósito

Este documento registra el uso de herramientas de Inteligencia Artificial durante el desarrollo del proyecto ROUTB, especificando las actividades en las que se utilizó, las respuestas obtenidas y los criterios aplicados por el equipo para aceptar, modificar o rechazar las sugerencias.

## Herramientas utilizadas

| Herramienta | Uso |
| --- | --- |
| ChatGPT (OpenAI) | Apoyo en la elaboración, revisión y mejora de documentación arquitectónica, decisiones de arquitectura y estructura inicial del proyecto. |
| Claude (Anthropic) | Apoyo en la elaboración, revisión y mejora de documentación arquitectónica, decisiones de arquitectura y estructura inicial del proyecto. |
| GitHub Copilot | Apoyo en la implementación del backend, incluyendo la creación de módulos y la organización de la estructura inicial. |
| Gemini | Apoyo en la estructuración, redacción y estandarización de la documentación técnica del proyecto. |
| Antigravity | Apoyo en la codificación del frontend, contenerización del backend con Docker, arquitectura de despliegue en la nube, observabilidad y documentación técnica. |
| Codex (OpenAI) | Apoyo en la implementación de funcionalidades específicas del backend, incluyendo la gestión de solicitudes grupales de cupos y la actualización del contrato de la API. |
| OpenCode | Apoyo en la creación y mantenimiento de código fuente, incluyendo la implementación de funcionalidades y la resolución de problemas técnicos. |


## Registro

### Semana 1

- **Actividad realizada:** Definición y documentación inicial del problema de ROUTB, incluyendo la necesidad identificada, los usuarios afectados, el objetivo, el alcance de la solución y el beneficio esperado. También se recibió apoyo para organizar la documentación inicial del repositorio.
- **Herramienta utilizada:** ChatGPT (OpenAI).
- **Contexto proporcionado:** Se proporcionó el contexto del proyecto ROUTB como una plataforma de movilidad colaborativa para estudiantes universitarios y se solicitó ayuda para estructurar y mejorar la definición del problema, identificar los usuarios principales y delimitar claramente el alcance de la solución. Posteriormente, se solicitó apoyo para organizar esta información dentro de los documentos del repositorio.
- **Respuesta que se obtuvo:** La IA propuso una redacción estructurada del problema y ayudó a diferenciar sus elementos principales: situación actual, necesidad, usuarios afectados, objetivo, alcance y beneficio esperado. También sugirió una organización inicial de la documentación del proyecto.
- **Qué se aceptó:** Se aceptó la estructura general de la documentación y la organización de los elementos que describen el problema de ROUTB. Se utilizaron las sugerencias para mejorar la claridad y coherencia de la redacción.
- **Qué se rechazó:** Se rechazaron o ajustaron las propuestas que ampliaban el alcance del proyecto más allá de lo definido por el equipo, así como funcionalidades no contempladas inicialmente.
- **Justificación:** La IA se utilizó como herramienta de apoyo para organizar y mejorar la documentación, pero la definición final del problema, los usuarios y el alcance fue validada por el equipo. Las decisiones que determinan qué resolverá ROUTB fueron tomadas a partir del contexto académico y de las necesidades identificadas para los estudiantes.
- **Fecha:** 2026-08-09

### Semana 2

- **Actividad realizada:** Desarrollo de la documentación arquitectónica inicial de ROUTB, incluyendo las tres primeras secciones de arc42, el árbol de utilidad, los escenarios de calidad y el modelado arquitectónico inicial mediante el diagrama C4 de contexto.
- **Herramientas utilizadas:** ChatGPT (OpenAI) y Claude (Anthropic).
- **Contexto proporcionado:** Se proporcionó a ambas herramientas la información del proyecto ROUTB y se solicitó apoyo para estructurar la documentación arquitectónica, definir los atributos y escenarios de calidad y representar el contexto del sistema mediante diagramas como código.
- **Respuesta que se obtuvo:** ChatGPT y Claude proporcionaron ideas y propuestas similares para organizar la documentación, definir los aspectos de calidad y estructurar el contexto arquitectónico del sistema. También se utilizaron sus respuestas para contrastar diferentes formas de representar y documentar la arquitectura.
- **Qué se aceptó:** Se aceptó el apoyo para estructurar las primeras secciones de arc42, elaborar el árbol de utilidad, definir los escenarios de rendimiento, usabilidad, seguridad, disponibilidad y escalabilidad, y desarrollar el diagrama C4 de contexto.
- **Qué se rechazó:** Se rechazaron propuestas o detalles que no correspondían al alcance definido por el equipo o que añadían información y decisiones que todavía no habían sido establecidas en el proyecto.
- **Justificación:** Se utilizaron ChatGPT y Claude para obtener y contrastar diferentes perspectivas. Aunque ambas herramientas proporcionaron ideas similares en varios aspectos, las propuestas fueron revisadas por el equipo y únicamente se incorporó la información que correspondía con el avance y las decisiones definidas para ROUTB.
- **Fecha:** 2026-08-15

### Semana 3

- **Actividad realizada:** Comparación de los estilos arquitectónicos de capas, hexagonal y monolito modular frente a los escenarios de calidad, documentación del ADR 0001 y creación del esqueleto ejecutable inicial del backend.
- **Herramientas utilizadas:** Claude (Anthropic) y GitHub Copilot.
- **Contexto proporcionado:** A Claude se le proporcionó la documentación del proyecto, los escenarios de calidad priorizados y las alternativas arquitectónicas que se querían evaluar. Se solicitó apoyo para comparar los estilos arquitectónicos, justificar la estrategia de solución y organizar la documentación correspondiente en arc42 y el ADR. A GitHub Copilot se le proporcionó el contexto de la arquitectura seleccionada y la estructura deseada para el backend, solicitando apoyo para crear y organizar el esqueleto ejecutable.
- **Respuesta que se obtuvo:** Claude ayudó a analizar y comparar la arquitectura por capas, la arquitectura hexagonal y el monolito modular frente a los escenarios de calidad del proyecto. También proporcionó apoyo para estructurar y mejorar la documentación de la estrategia de solución y del ADR 0001. GitHub Copilot ayudó principalmente en la creación del esqueleto ejecutable del backend, la organización inicial de los módulos y la estructura necesaria para que la aplicación pudiera arrancar y contar con una prueba automática.
- **Qué se aceptó:** Se aceptó el análisis comparativo de los tres estilos arquitectónicos y la documentación generada a partir de este análisis. Como resultado, se aceptó el monolito modular como estilo arquitectónico para el backend de ROUTB, al presentar el mejor balance frente a las prioridades del proyecto. También se aceptó la estructura inicial del esqueleto ejecutable, incluyendo los módulos de autenticación, recorridos, búsqueda, reputación y administración.
- **Qué se rechazó:** Se rechazó adoptar la arquitectura por capas y la arquitectura hexagonal como estilos principales del backend. También se rechazó añadir lógica de negocio completa al esqueleto ejecutable, ya que en esta etapa su propósito era evidenciar y validar la estructura arquitectónica inicial.
Justificación: Las herramientas fueron utilizadas con propósitos diferentes. Claude sirvió como apoyo para el análisis de las alternativas arquitectónicas y la elaboración de la documentación, mientras que GitHub Copilot se utilizó principalmente para apoyar la implementación del esqueleto ejecutable. Las propuestas obtenidas fueron revisadas por el equipo y solo se aceptaron aquellas que correspondían con las prioridades de calidad, el alcance y las decisiones arquitectónicas definidas para ROUTB.
- **Fecha:** 2026-08-23

### Semana 4

- **Actividad realizada:** Documentación de las Secciones 5, 6, 9, 10 y 12 de arc42, automatización de la separación de la documentación de un solo archivo a 12 archivos independientes, validación del diagrama C4 (Nivel 2) e implementación del flujo inicial de vistas de la aplicación móvil.
- **Herramientas utilizadas:** Gemini y Antigravity.
- **Contexto proporcionado:** Borradores de componentes, un documento base consolidado y diagramas, junto con requerimientos funcionales y de experiencia de usuario para el flujo de autenticación móvil.
- **Respuesta que se obtuvo:** Organización tabulada de la estructura del sistema, redacción de introducciones para requisitos de calidad, generación de los 12 archivos markdown separados, código funcional de las pantallas con validaciones y redacción de escenarios de ejecución estructurados por capas con diagramas.
- **Qué se aceptó:** El formato en tablas, la inclusión explícita de las integraciones externas, la división modular de la documentación en múltiples archivos, el código de las vistas móviles y el modelo conceptual por capas para los escenarios de ejecución.
- **Qué se rechazó:** Versiones preliminares incompletas donde faltaban componentes externos y descripciones de escenarios basadas únicamente en listas mecánicas sin profundidad técnica.
- **Justificación:** Las herramientas se utilizaron para construir el flujo inicial de autenticación móvil, estandarizar la documentación técnica y automatizar la organización del proyecto en archivos individuales, asegurando total coherencia entre el diseño teórico y el código implementado.
- **Fecha:** 2026-08-30.

### Semana 5

- **Actividad realizada:** Definición del reto de disponibilidad y concurrencia de cupos, implementación del flujo de recorridos y reservas en el backend, creación del ADR del reto 0003 y actualización de la trazabilidad entre requisitos, C4, código, pruebas y evidencia.
- **Herramientas utilizadas:** GitHub Copilot.
- **Contexto proporcionado:** Se trabajó con el repositorio de ROUTB, su documentación arquitectónica, el flujo existente del backend y los criterios de calidad definidos para la gestión de recorridos y cupos. El análisis se centró en fortalecer el comportamiento del sistema ante solicitudes simultáneas y en respaldar la solución con evidencia técnica y mediciones comparables.
- **Respuesta que se obtuvo:** Se propuso priorizar el control de concurrencia de cupos. Se creó el módulo `trips` con endpoints para crear, consultar y reservar recorridos, y se implementó una actualización atómica de la disponibilidad para evitar la sobreventa.
- **Qué se aceptó:** Se aceptó el reto de disponibilidad y concurrencia porque se relaciona directamente con el objetivo principal de ROUTB. También se aceptaron el modelo de recorridos, el servicio de reservas, la prueba de 20 intentos sobre 4 cupos, el ADR 0003 y las actualizaciones de los requisitos de calidad y del contexto C4.
- **Qué se rechazó:** Se rechazó modificar los diagramas existentes del C4, alterar el workflow original del backend CI o incluir detalles técnicos internos de la implementación en la explicación arquitectónica.
- **Justificación:** El cambio fue revisado contra la arquitectura existente y se mantuvo dentro de los límites del contenedor API Backend, la base de datos y el módulo `trips`. La prueba confirmó 4 reservas exitosas de 20 intentos, 0 cupos restantes y un tiempo de respuesta inferior a 3,99 segundos. También se midió la línea base sobre la versión anterior, donde los 20 intentos no servian porque el endpoint no existía.
- **Fecha:** 2026-09-05.

### Semana 6

- **Actividad realizada:** Actualización de la arquitectura y del backend para la gestión de recorridos y solicitudes, junto con la documentación de los cambios.
- **Herramienta utilizada:** GitHub Copilot y Antigravity.
- **Contexto proporcionado:** Código, documentación arc42, mapa de contextos, C4, ADR y criterios de evaluación del proyecto.
- **Respuesta que se obtuvo:** Se implementó `TripRequest`, su migración y endpoints; se actualizaron los recorridos con conductor, horario y estado; y se revisaron el mapa de contextos, la tabla de propiedad de datos, las violaciones y sus planes de corrección, la sección 8 de arc42, el C4 nivel 3 y el ADR.
- **Qué se aceptó:** La separación entre `trips` y `requests`, la cobertura de las entidades existentes, la asignación de un único dueño por entidad y la actualización de los diagramas y documentos relacionados.
- **Qué se rechazó:** Cambios fuera del alcance y funcionalidades no implementadas, como notificaciones persistentes o una entidad propia de administración.
- **Justificación:** Los cambios se contrastaron con el código actual y con los límites de los contextos del sistema, manteniendo la trazabilidad entre arquitectura, implementación y documentación.
- **Fecha:** 2026-09-13.

### Semana 7

- **Actividad realizada:** Definición y versionamiento del contrato de la API, creación de las pruebas que verifican que el contrato y la implementación coincidan, documentación del ADR sobre la forma en que los componentes se comunican entre sí, ampliación de los flujos de ejecución con el escenario de reserva de cupo, y evidencia que demuestra que la prueba de contrato detecta y rechaza cambios incompatibles en la API.
- **Herramienta utilizada:** Antigravity.
- **Contexto proporcionado:** Se proporcionó la estructura del proyecto, el contrato OpenAPI existente, las pruebas del backend, el pipeline de CI y la documentación arc42 y de ADRs. Se solicitó apoyo para identificar qué faltaba en la documentación y el código, para generar los artefactos necesarios, y para producir evidencia verificable de que la prueba de contrato detecta cambios incompatibles.
- **Respuesta que se obtuvo:** La herramienta identificó que el proyecto ya contaba con el contrato y las pruebas, pero que faltaba documentar la decisión sobre cómo los componentes se comunican entre sí (síncrono o asíncrono) y que la sección 6 de arc42 no incluía el flujo de reserva de cupo, que es el más relevante del sistema. También propuso el contenido del ADR, del escenario de ejecución y del archivo de evidencia con la salida real de pytest ante un breaking change simulado.
- **Qué se aceptó:** Se aceptó crear el ADR 0004 sobre la integración síncrona mediante REST, ligado al escenario de cupos y con la alternativa asíncrona descartada. También se aceptó el escenario 6.3 de reserva de cupo en arc42, que documenta el flujo completo con sus dos posibles resultados: confirmación o rechazo por falta de cupos. Finalmente, se aceptó la evidencia de que la prueba falla ante un cambio incompatible, incluye la salida real de la ejecución de pytest y la traza del error producido al eliminar la ruta `/trips/` de la implementación.
- **Qué se rechazó:** Se descartó plantear la integración asíncrona como la estrategia principal del sistema, ya que el flujo de reserva exige una respuesta inmediata que el modelo asíncrono no puede garantizar sin añadir componentes de mensajería que no forman parte del alcance del proyecto.
- **Justificación:** Los artefactos generados se contrastaron con el código existente y con las decisiones previas del equipo. El ADR 0004 complementa al ADR 0003 y a las pruebas de concurrencia ya existentes, y el escenario 6.3 cierra el vacío entre la decisión técnica documentada y su representación en la vista de ejecución de arc42. La evidencia de detección de breaking changes se generó ejecutando las pruebas reales y capturando la salida, sin alterar el código ni el contrato versionado.
- **Fecha:** 2026-09-19

### Semana 8

- **Actividad realizada:** Selección y evaluación de la plataforma de despliegue en la nube a costo cero ($0.00 USD) y sin tarjeta de crédito (ADR 0005), contenerización del backend mediante Docker, configuración de despliegue en Render y Supabase, implementación de observabilidad con logging estructurado en JSON a stdout y endpoint de health check (`/health`), actualización de las secciones 2, 7 y 8 de arc42, actualización de la matriz de aspectos (Aspecto 5), y documentación de evidencias técnicas (estimación de costos mensuales, análisis de punto de ruptura y verificación de disponibilidad externa con curl).
- **Herramienta utilizada:** Antigravity.
- **Contexto proporcionado:** Requisitos de la Semana 8 sobre despliegue en la nube, observabilidad y costos; restricciones del proyecto de costo nulo ($0 USD) y ausencia de tarjetas de crédito; arquitectura existente del backend (FastAPI, PostgreSQL); configuración de contenedores Docker y estructura de documentación en arc42.
- **Respuesta que se obtuvo:** Propuesta de arquitectura de hosting combinando Render (Web Service gratuito) y Supabase (PostgreSQL gratuito); diseño del `Dockerfile` multi-stage con usuario no privilegiado (`appuser`) y manifiesto `render.yaml`; diseño e implementación del middleware de logging estructurado JSON en FastAPI y pruebas de disponibilidad en `test_health.py`; redacción del ADR 0005, vista de despliegue (sección 7 de arc42 con diagramas C4 en Mermaid), sección 2 (restricciones comerciales y presupuestarias), sección 8 (gestión de secretos con `.env.example` y observabilidad), y los informes de estimación de costos y verificación externa vía curl.
- **Qué se aceptó:** Se aceptó la adopción de Render y Supabase para el despliegue a costo cero sin tarjetas bancarias; el ADR 0005; el `Dockerfile` seguro sin usuario root; el manifiesto `render.yaml`; el middleware de logs estructurados a `stdout`; el endpoint `/health` y sus pruebas automatizadas; las actualizaciones en arc42 (secciones 2, 7 y 8); la incorporación del Aspecto 5 en `aspectos.md`; y los documentos de evidencia técnica de costos y verificación externa.
- **Qué se rechazó:** Se descartó el uso de nubes principales (AWS, GCP, Azure) o servicios como Fly.io debido a la exigencia de tarjeta de crédito para la activación de cuentas, y Railway por limitar su capa gratuita a periodos de prueba temporales. También se rechazó almacenar secretos o credenciales en el repositorio, así como la integración de agentes de observabilidad pesados o de pago, prefiriendo la ingestión nativa de logs JSON desde `stdout` en Render.
- **Justificación:** Las decisiones adoptadas garantizan la viabilidad operativa del sistema en un entorno cloud público accesible vía HTTPS, garantizando la observabilidad y trazabilidad operativa sin infringir las restricciones presupuestarias del proyecto. Todo cambio fue revisado por el equipo, asegurando la correspondencia entre la infraestructura como código, la arquitectura documentada y las pruebas ejecutadas.
- **Fecha:** 2026-09-24

### Semana 9

- **Actividad realizada:** Análisis e implementación de solicitudes grupales de cupos en ROUTB, actualización del contrato y de la app móvil, revisión de límites entre `requests` y `trips`, y preparación de pruebas y evidencia arquitectónica.
- **Herramienta utilizada:** Codex (OpenAI) y GitHub Copilot.
- **Contexto proporcionado:** El equipo seleccionó que un pasajero pueda reservar hasta cuatro cupos contando el suyo, para un máximo de tres acompañantes sin cuenta. El conductor decide sobre el grupo completo y cancelar la reserva debe liberar todos los cupos. También se indicó que no se integre IA al runtime ni se agregue una dependencia para esta Porción.
- **Respuesta que se obtuvo:** Se propuso persistir la cantidad con compatibilidad por defecto de un cupo, coordinar estado y disponibilidad en una transacción, aplicar el ajuste de inventario mediante operaciones públicas de `trips`, exponer la cantidad por API y app móvil y probar la aceptación/cancelación de grupos y la concurrencia.
- **Qué se aceptó:** Se aceptó el alcance grupal de 1–4 personas, la aceptación o rechazo completos, la liberación de todos los cupos al cancelar, el valor por defecto de uno y las operaciones condicionales atómicas del módulo `trips`. La implementación se revisa mediante el conjunto de pruebas y el contrato OpenAPI.
- **Qué se corrigió:** La propuesta inicial permitía solicitar hasta la capacidad disponible sin máximo explícito. El equipo aclaró que el límite es cuatro personas incluyendo al pasajero. Se ajustaron validación, interfaz y persistencia a ese límite.
- **Qué se rechazó:** Se rechazó añadir Excel/dependencias como extensión de la Porción y se descartó incorporar IA generativa dentro de ROUTB. No se crean cuentas ni se recolectan datos de acompañantes.
- **Justificación:** El alcance y las reglas de negocio fueron definidos por el equipo. Las recomendaciones de implementación se contrastan con el código, la propiedad de datos y los resultados reales de pruebas; la IA no toma decisiones de aceptación ni de disponibilidad en producción.
- **Fecha:** 2026-10-02

### Semana 10

- **Actividad realizada:** Respuesta documental y técnica a la rúbrica del segundo corte, que pedía escenario operativo caracterizado, decisión implementada, operación con observabilidad, trazabilidad arquitectónica y sustentación. Ante la ausencia de escenario asignado, el equipo declaró el suyo propio (concurrencia sin sobreventa como protagonista y p95 de `GET /trips/` como secundario) con hipótesis, montaje, variables y umbrales por escrito; se aportó la medición final comparable contra la línea base, se completó la trazabilidad (fila 7 de aspectos, arc42 09 con ADR 0012/0013, contrato 0.6.0 verificado), se dejó el CI con el job Sonar reservado, se barrió el repositorio de secretos y se verificó la versión publicada en Render; además se dejaron en verde las suites que respaldan la decisión. También se realizó la fundación de datos (PostGIS con la migración 006, CI y base de pruebas con Alembic, ADR 0009), la geocodificación con caché, el cálculo de rutas y el consentimiento de ubicación con su purga (ADR 0010 y 0011), y las sugerencias de matching con las solicitudes con paradas y las notificaciones push (ADR 0012 y 0013).
- **Herramienta utilizada:** OpenCode (Muse Spark).
- **Contexto proporcionado:** Matriz S10 con 10 rubros no verificados y rúbrica de cinco criterios (caracterización, decisión, operación, trazabilidad, sustentación); `SEMANA9.md` como plantilla; suites en rojo al inicio (16 backend, 6 Flutter); despliegue publicado desactualizado frente al contrato del repo.
- **Respuesta que se obtuvo:** Estructura de evidencia espejada de S9 para cada criterio de la rúbrica, escenario propio medible con sus umbrales, y correcciones mínimas de código con causa identificada antes de cambiar nada.
- **Qué se aceptó:** El escenario de concurrencia con sus umbrales (cero sobreventas; p95 < 3,99 s), la medición local final (p95 1,1860 s), la evidencia `SEMANA10.md` con pendientes declarados, y las correcciones de pruebas y pantallas verificadas por ejecución.
- **Qué se corrigió:** La primera hipótesis sobre tablas ausentes apuntaba al código y la evidencia mostró contaminación entre sesiones concurrentes; el despliegue publica 0.4.0 frente al contrato 0.6.0, lo que se declaró como pendiente vía merge a `master` en vez de presentarlo como alineado.
- **Qué se rechazó:** Presentar la reserva grupal o el rendimiento como respuesta al reto sin declararlos escenario propio; reformatear todo el repositorio con el SDK nuevo; regenerar el contrato sin cambios; y declarar cumplida la rúbrica sin redespliegue, sin Sonar corriendo ni prueba en dispositivo real.
- **Justificación:** Cada criterio de la rúbrica quedó con su evidencia ejecutada y sus pendientes nombrados. La IA propuso y el equipo dispuso tras evidencia de ejecución.
- **Fecha:** 2026-10-11

### Semana 10 (corte 2, degradación controlada)

- **Actividad realizada:** Decisión e implementación de degradación controlada ante caída de Photon/Nominatim/OSRM: timeout único configurable, no persistencia de rutas degradadas, pruebas con `timeout` en el nombre y medición con/sin fallo con p95 exactos.
- **Herramienta utilizada:** OpenCode (Muse Spark).
- **Contexto proporcionado:** Plan `plan-final-corte2-routb.md` con 9 correcciones al plan anterior; servicios con timeout fijo de 3,0 s y caché que guardaba degradados; prueba N=50 que colisionaba en caché por redondeo a 5 decimales.
- **Respuesta que se obtuvo:** Parametrizar `ROUTING_TIMEOUT_SECONDS` (1,4 s), aplicarlo a Photon/Nominatim, no cachear `degraded=true`, y aislar ramas del experimento con coordenadas separadas por caso.
- **Qué se aceptó:** El default de 1,4 s respaldado por temporización real (3,24/3,03 s con 3,0 frente a 1,42/1,43 s con 1,4); la corrección del aislamiento de caché verificada por ejecución.
- **Qué se corrigió:** La segunda prueba de geocode propagaba `TimeoutException` por encima de los manejadores reales; se reescribió para atravesarlos. La rama con fallo de la prueba N=50 leía de caché la ruta sana por colisión de claves.
- **Qué se rechazó:** Reintentos automáticos (multiplican latencia en plan gratuito) y declarar cumplida la medición sin valores exactos de p95.
- **Justificación:** Cada cambio se verificó ejecutando la prueba afectada; la decisión de timeout quedó registrada en el ADR 0014 sin estado provisional.
- **Fecha:** 2026-10-13

### Semana 11

- **Actividad realizada:** Identificación de línea base de integración y mitigaciones en código; construcción de tabla de modos de fallo (no responde, responde tarde, petición duplicada); análisis de idempotencia y patrón Saga en el flujo de solicitudes de cupos; elaboración del ADR 0017 de evaluación de extracción a microservicios; actualización de riesgos y deuda técnica en la sección 11 de arc42; e incorporación del Aspecto 10 en `docs/aspectos.md`.
- **Herramienta utilizada:** Antigravity.
- **Contexto proporcionado:** Rúbrica de 9 criterios de la actividad de integración, resiliencia y modos de fallo; repositorio ROUTB (Flutter, FastAPI, backend desplegado en Dokploy y PostgreSQL en Supabase); directrices de AGENTS.md y decisiones previas (ADR 0001 a 0016).
- **Respuesta que se obtuvo:** Localización técnica de la integración síncrona cliente-servidor mediante greps en código; tabla detallada de modos de fallo con mitigaciones implementadas y pendientes; análisis de transacciones ACID locales y diseño de Saga compensatoria hipotética; redacción formal del ADR 0017 argumentando la decisión de "no extraer" el módulo `requests` con criterios reales de equipo, datos, frecuencia de cambio y costo operativo; actualización de arc42 sección 11 (modos de fallo como riesgos del sistema y mitigaciones pendientes como deuda técnica); actualización de la matriz de aspectos (Aspecto 10); y documento consolidado de evidencia en `docs/evidencia/resiliencia-y-modos-de-fallo.md`.
- **Qué se aceptó:** Se aceptó la delimitación de la integración cliente-servidor sobre solicitudes de cupos como objeto de análisis; las mitigaciones concretas basadas en el código existente (`timeout = 35s`, `onRetry`, verificación de unicidad en BD); la decisión de no extraer `requests` a microservicio; y la formalización de las mitigaciones pendientes (Idempotency-Key, backoff/jitter, Circuit Breaker) como deuda técnica con cronograma para Q1-Q2 2027.
- **Qué se rechazó:** Se descartó una justificación superficial para el ADR de extracción basada en "falta de tiempo", exigiendo criterios objetivos de arquitectura (equipo de 4 personas, costo $0 USD, acoplamiento transaccional de cupos y frecuencia de despliegue). También se rechazó dar por ejecutado o aprobado `pytest` sin constatar la conectividad real con la base de datos de pruebas.
- **Justificación:** El análisis garantiza la coherencia arquitectónica entre el código implementado, los riesgos operativos del despliegue en la nube y las decisiones de diseño del equipo, cumpliendo la totalidad de los criterios de evaluación sin introducir regresiones ni acoplamientos innecesarios.
- **Fecha:** 2026-10-17

### Semana 12

- **Actividad realizada:** La semana se dedicó a la estrategia de datos y eventos. Se crearon los ADR 0018 (uso de Google Maps en el cliente), 0019 (renderizado de mapas), 0020 (decisión de datos más costosa de revertir) y 0021 (integridad de las solicitudes). En arc42 se crearon la tabla de operaciones y garantías de consistencia (§8.6) y la estrategia de consistencia e invalidación de caché (§8.7); se dejó constancia de que no hay un flujo por eventos, porque las notificaciones son un complemento y no la fuente de verdad; y se revisó el C4 nivel 2 con la base de datos como contenedor. Se actualizaron las secciones 2, 5, 6, 8, 9, 10 y 11, la matriz de aspectos y el catálogo de decisiones. Se crearon las evidencias de la política de invalidación de caché y de concurrencia de solicitudes, y se actualizó la guía de despliegue. En código se trasladó la geocodificación al cliente, se retiró la geocodificación del backend y se agregó la garantía de una sola solicitud activa por pasajero y viaje, con sus pruebas de concurrencia.
- **Herramienta utilizada:** OpenCode (DeepSeek V4.1 Flash).
- **Contexto proporcionado:** Rúbrica de la semana 12 (tabla de operaciones y garantías, dos operaciones contrastadas, diseño de caché e invalidación, garantías del flujo por eventos, ADR de la decisión de datos más costosa, C4 nivel 2 y arc42 §8), historial de la semana, código del sistema y restricciones del proyecto.
- **Respuesta que se obtuvo:** El mapa de la rúbrica contra los documentos creados, la detección de documentación desactualizada, la redacción del ADR 0021, la tabla y la estrategia de caché, y el plan de verificación con pruebas de concurrencia.
- **Qué se aceptó:** Los cuatro ADR, la tabla de operaciones y garantías, la estrategia de caché y su invalidación, el argumento del ADR 0020, la base de datos como contenedor en el C4 nivel 2, la guía de despliegue actualizada y las pruebas de concurrencia.
- **Qué se corrigió:** La documentación que describía mecanismos ya retirados; la guía de despliegue que seguía apuntando a la plataforma anterior; la validación de solicitudes duplicadas, que tenía una ventana de carrera; y el manejo de aceptar o rechazar una solicitud retirada al mismo tiempo.
- **Qué se rechazó:** Inventar un flujo por eventos o un broker que el sistema no usa; agregar bloqueos o cambios de aislamiento sin una decisión que los justifique; reformatear archivos ajenos a la semana; y aplicar cambios de base de datos en producción sin autorización.
- **Justificación:** La rúbrica quedó cubierta con documentos creados y verificables, y la tabla se contrastó con dos operaciones reales del sistema. Las pruebas de backend quedaron en verde (95) y las de frontend también (138), con el análisis y la compilación correctos; los pendientes quedaron declarados.
- **Fecha:** 2026-10-25

## Observaciones

La Inteligencia Artificial se utiliza como una herramienta de apoyo durante el desarrollo y la documentación del proyecto. Las respuestas generadas no se incorporan automáticamente: son revisadas, contrastadas con el contexto y los requisitos del proyecto y, cuando corresponde, modificadas o rechazadas por el equipo.

Las decisiones relacionadas con el alcance, las restricciones, la arquitectura y los criterios de calidad son responsabilidad del equipo de desarrollo. La IA se emplea principalmente para apoyar el análisis, la organización de la información, la exploración de alternativas y la mejora de la documentación.

