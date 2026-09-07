# Evaluación Crítica de la Retroalimentación de la IA (Proyecto ROUTB)

Este documento presenta una revisión argumentada de las observaciones generadas por la IA evaluadora sobre las entregas del proyecto ROUTB. El objetivo es contrastar el rigor automatizado de la IA (que tiende a penalizar discrepancias estrictamente formales o de plantilla) con la sustancia real del contenido arquitectónico entregado. Se demuestra que varios hallazgos catalogados como "No cumple" poseen el mérito técnico suficiente para ser reconsiderados como "Cumple parcialmente" o "Cumple".

## Análisis Profundo: Semana 2

La IA evaluadora fue excesivamente estricta en la iteración de la Semana 2. Gran parte del contenido penalizado por formato (falta de columnas específicas, títulos exactos o ubicaciones predeterminadas) **sí existe en sustancia** dentro de la documentación del repositorio. A continuación se desglosa la defensa en formato tabular:

| Criterio Evaluado | Observación literal de la IA | Refutación y Argumento (Sustancia vs. Forma) |
| :--- | :--- | :--- |
| **Restricciones de arquitectura** | Completar con categorías organizativas y legales. | **Cumple parcialmente:** Aunque no se usan los encabezados exactos ("Legal" u "Organizativa"), el texto excluye la verificación de antecedentes por requerir *procesos legales* y bases de datos oficiales (restricción legal explícita). Asimismo, condiciona el desarrollo al *cronograma académico* semestral (restricción organizativa clásica). El contenido está; falta la etiqueta formal. |
| **Escenarios de calidad** | Desglosar las 6 partes; la medida necesita cifra, unidad y condición de carga. | **Cumple parcialmente:** Las 6 partes (fuente, estímulo, artefacto, entorno, respuesta, medida) están presentes en prosa dentro de las columnas "Escenario" y "Medida", cumpliendo la estructura. Se le concede a la IA que falta la "condición de carga" en la mayoría (salvo en Escalabilidad), pero la penalización total es desproporcionada frente al esfuerzo estructural logrado. |
| **Árbol de utilidad** | Debe priorizar por impacto y riesgo y casar con los escenarios. | **Cumple parcialmente:** La priorización exigida sí existe, pero fue documentada en la tabla inmediatamente anterior ("Objetivos de calidad"), la cual clasifica los mismos atributos en una escala de prioridad del 1 al 8. La lógica de negocio está priorizada, solo que en una matriz contigua en lugar de las ramas del diagrama. |
| **Diagrama C4 de Contexto** | Necesita leyenda, flechas etiquetadas y un solo nodo para el sistema. | **Cumple parcialmente:** Las flechas de conexión en el código Mermaid son claramente visibles y definen el flujo de interacción. Además, otros diagramas dentro de la misma documentación global sí detallan los protocolos en las flechas (HTTPS, API, Push), demostrando dominio técnico de la herramienta, aunque el archivo `docs/c4/context.md` tenga fallos de leyenda. |
| **Ubicación y Trazabilidad** | Reubicar en sección 10; enlazar cada escenario en `aspectos.md`. | **Observación de formato válida, pero menor:** La IA penaliza que la sección 10 quedó vacía y que falta un hipervínculo cruzado. Esto es un detalle de ofimática (mover texto y crear un link), no un fallo en el diseño de la arquitectura del software. |

---

## Revisión Argumentada: Otras Semanas

### Semana 1
*   **Observaciones de la IA:** Faltan dos tensiones de calidad explícitas, la tabla de aspectos está incompleta (falta ID y columnas) y el archivo `docs/ia.md` quedó en pendiente.
*   **Análisis y Refutación:** La IA acierta en señalar los vacíos formales de las plantillas (la matriz de aspectos no tiene las 8 columnas). Sin embargo, sobre la exigencia de declarar "tensiones de calidad", la IA resulta miope ante el contexto del dominio: las tensiones ya están implícitas en los objetivos de negocio descritos en el arc42 (por ejemplo, equilibrar la reducción de tiempos de espera de los estudiantes frente a la validación de seguridad requerida mediante el correo institucional). Se le podría discutir un "cumple parcialmente" interpretando el contexto del negocio, aunque formalmente falte el párrafo declarativo.

### Semana 3
*   **Observaciones de la IA:** Falta enlace al ADR desde el escenario (sección 10.2), el README tiene pasos separados (pide un único comando), la prueba no tiene workflow de CI y el C4 sigue sin leyenda.
*   **Análisis y Refutación:** La evaluación es mixta. La IA acierta al requerir el archivo YAML para automatizar las pruebas (CI workflow). No obstante, exigir que el README tenga un "único comando documentado" para instalación y arranque es un capricho de *Developer Experience (DevEx)* de la IA, no un defecto real de la arquitectura del sistema; documentar pasos separados es perfectamente válido y a veces más didáctico. Respecto al diagrama C4, la IA simplemente arrastra su crítica estricta de la Semana 2 sin reevaluar si el modelo de contexto comunica eficazmente las integraciones (que sí lo hace).

### Semana 4 (S4)
*   **Observaciones de la IA:** Reconoce un avance sólido (arc42 redactado, C4 niveles 1 y 2 en código, corte vertical con CI en verde). Señala que faltan las secciones 7, 8 y 11, llenar huecos en `aspectos.md`, añadir SonarCloud, medir la línea base y enlazar el ADR al commit.
*   **Análisis y Refutación:** Esta es la semana donde la IA es más equilibrada. Reconoce el mérito técnico pesado (el código pasa las pruebas en verde y los diagramas estructurales están bien hechos). Sus críticas son justas pero deben entenderse puramente como un *checklist operativo* para cerrar el corte. No atacan la calidad de la arquitectura diseñada, sino que marcan los "huecos" literales de las plantillas y la falta de integración de una herramienta externa (SonarCloud).

### Semana 5 (Corte 1)
*   **Observaciones de la IA:** Afirma que no hay etiqueta `corte-1`, no hay diagnóstico, no hay ADR del reto, ni implementación de pruebas o configuración de SonarCloud.
*   **Análisis y Refutación (Problema de Sincronización):** La retroalimentación de la IA en esta semana es **completamente inválida por desactualización**. Sus observaciones sobre los "faltantes" masivos se deben a que la IA no ha actualizado su calificación para reflejar el estado actual y real del repositorio. Se trata de una evaluación mecánica y prematura basada en una versión anterior al cierre definitivo del corte. Por lo tanto, esta revisión ignora por completo los commits recientes, las etiquetas creadas y los entregables que el equipo ya subió al repositorio para cumplir con los requerimientos del reto.
