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
| Antigravity | Apoyo en la codificación e implementación inicial del frontend, incluyendo el diseño funcional del flujo de autenticación y validaciones. |


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

## Observaciones

La Inteligencia Artificial se utiliza como una herramienta de apoyo durante el desarrollo y la documentación del proyecto. Las respuestas generadas no se incorporan automáticamente: son revisadas, contrastadas con el contexto y los requisitos del proyecto y, cuando corresponde, modificadas o rechazadas por el equipo.

Las decisiones relacionadas con el alcance, las restricciones, la arquitectura y los criterios de calidad son responsabilidad del equipo de desarrollo. La IA se emplea principalmente para apoyar el análisis, la organización de la información, la exploración de alternativas y la mejora de la documentación.
