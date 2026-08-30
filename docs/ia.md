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

## Observaciones

La Inteligencia Artificial se utiliza como una herramienta de apoyo durante el desarrollo y la documentación del proyecto. Las respuestas generadas no se incorporan automáticamente: son revisadas, contrastadas con el contexto y los requisitos del proyecto y, cuando corresponde, modificadas o rechazadas por el equipo.

Las decisiones relacionadas con el alcance, las restricciones, la arquitectura y los criterios de calidad son responsabilidad del equipo de desarrollo. La IA se emplea principalmente para apoyar el análisis, la organización de la información, la exploración de alternativas y la mejora de la documentación.
