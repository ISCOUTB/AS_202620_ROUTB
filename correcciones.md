# Informe sobre la retroalimentación

Este documento atiende a la directriz docente orientada a evaluar la coherencia de la retroalimentación consignada en el repositorio `ISCOUTB/AS_202620_feedback`. Su propósito es identificar y evidenciar, de manera objetiva y sin alterar los artefactos evaluados, aquellos aspectos en los que los informes de revisión dan por ausentes o incompletos elementos que efectivamente se encontraban incorporados y disponibles en este repositorio al momento de los respectivos cortes.

## 1. Commits y estados revisados

A continuación se relacionan las revisiones registradas en la retroalimentación junto con el estado del repositorio declarado para cada evidencia:

| Revisión | Commit que declara haber mirado | Fecha del commit | Cierre de la actividad |
| :--- | :--- | :--- | :--- |
| Evidencia S1 | `68b0b05d` | 2026-08-09T14:48:08-05:00 | 2026-08-10T05:00:00Z |
| Evidencia S2 | `14e66888` | 2026-08-16T12:44:08-05:00 | 2026-08-17T05:00:00Z |
| Evidencia S3 | `1ed002b2` | 2026-08-23T20:31:54-05:00 | 2026-08-24T05:00:00Z |

---

# 2. Semana 1

## 2.1 Matriz de la ficha

| Criterio | Evidencia técnica | Estado | Observaciones |
| :--- | :--- | :--- | :--- |
| Repositorio creado en la organización con el nombre de la convención | `revisiones/2026-2/_meta/lsremote.txt:14` (`AS_202620_ROUTB OK`); protocolo git sin autenticación | Cumple | Visible y público, nombre correcto |
| Integrantes del equipo con acceso | `git shortlog -sne 68b0b05` : solo `MKeinerrr` (2 identidades consolidadas: `correo omitido` + `correo omitido`) y `junior14700` | No verificado | Sin API no se pueden listar colaboradores. En el historial hasta el cierre solo constan 2 cuentas; las otras 2 (`diegobrr999-commits`, `juliandmanjarrez-tech`) empujan desde el 13-ago, lo que sugiere acceso. Haría falta el listado de colaboradores o confirmación en la sustentación |
| Equipo de 3 o 4 personas | `EQUIPOS.md:30` | Cumple | 4 integrantes declarados |
| Ficha del problema con usuarios y alcance | `docs/problema.md` (en `68b0b05`) | Cumple | Usuarios: pasajeros, conductores, administradores; alcance: consulta de rutas/cupos y reserva |
| Dos tensiones de calidad declaradas y enfrentadas entre sí | `git grep -niE 'tension\|tensión\|calidad' 68b0b05 -- docs README.md`: sin resultados | No cumple | Sin resultados en `docs` ni `README.md` |
| `docs/aspectos.md` con la tabla y un aspecto en sus dos primeras columnas | `docs/aspectos.md` en `68b0b05` | No cumple | La tabla tiene solo 2 columnas (Aspecto/Descripción), no las 8 del curso, y la fila no lleva ID |
| `docs/ia.md` iniciado con contenido real | `docs/ia.md` en `68b0b05` | No cumple | Solo plantilla: tabla de herramientas vacía («—») y «Pendiente por documentar»; no hay entrada real ni declaración de no uso |
| Plantilla arc42 descomprimida en `docs/arc42/`, en Markdown | `docs/arc42/arc42-template-EN.md` en `68b0b05` | Cumple | Un archivo Markdown con los 12 encabezados de sección (líneas 18–207); sin rellenar, como se espera en S1 |
| `docs/adr/` y `docs/c4/` creados | `git ls-tree -r 68b0b05` : `docs/adr/.gitkeep`, `docs/c4/.gitkeep` | Cumple | Ambos directorios versionados con `.gitkeep` |

**Resultado informado por el autocalificador: 5 de 9 criterios cumplidos en la matriz de la ficha.**

## 2.2 Contraste con el estado actual

| Origen | Hallazgo | Acción realizada | Evidencia actual | Estado |
| :--- | :--- | :--- | :--- | :--- |
| S1 | Participación inicialmente visible de solo 2 cuentas al cierre de la actividad | El historial posterior consolida los commits y la actividad colaborativa de los cuatro integrantes del equipo | Historial Git / `git shortlog -sne HEAD` | Corregido |
| S1 | No estaban explicitadas las tensiones de calidad enfrentadas entre sí | Se definieron y contrastaron los objetivos y tensiones de calidad clave (ej. rendimiento frente a seguridad en el uso de hashing/JWT, y disponibilidad frente a concurrencia en reservas) | `docs/arc42/01_introduccion_y_objetivos.md` (sección 1.4) y `docs/arc42/10_requisitos_de_calidad.md` | Corregido |
| S1 | `docs/aspectos.md` con tabla de solo 2 columnas y sin ID | Se reestructuró la matriz a 9 columnas completas con identificadores numéricos, requisitos asociados, contextos y trazabilidad hacia C4, ADR, código, pruebas y evidencia | `docs/aspectos.md` | Corregido |
| S1 | `docs/ia.md` iniciado solo con plantilla vacía («Pendiente por documentar») | Se completó la bitácora exhaustiva del uso de IA con herramientas, contexto, respuesta obtenida, aceptado, rechazado y justificación de la S1 a la S5 | `docs/ia.md` | Corregido |

---

# 3. Semana 2

## 3.1 Matriz de la ficha

| Criterio | Evidencia técnica | Estado | Observaciones |
| :--- | :--- | :--- | :--- |
| arc42 sección 1 con objetivos de negocio y su interesado | `docs/arc42/arc42-template-EN.md:18-103` en `14e6688` | No cumple | Hay «Objetivos de calidad» (líneas 44-53) y tabla de Stakeholders (95-103), pero ningún objetivo dice a quién le importa, y los «Objetivos específicos» (28-35) son funcionalidades |
| arc42 sección 2 con restricciones clasificadas y justificadas | `docs/arc42/arc42-template-EN.md:106-147` | No cumple | Cada restricción está justificada («dado que...»), pero la clasificación es propia (técnicas / integración / comerciales y de alcance): no hay categorías organizativas ni legales |
| Restricciones separadas de los requisitos | sección 2 (106-147) vs «Descripción general de los requisitos» (36-42) | Cumple | Las restricciones están en su sección; ninguna es un requisito funcional disfrazado |
| arc42 sección 3 con actores y sistemas externos | `docs/arc42/arc42-template-EN.md:148-256` | No cumple | Identifica actores y sistemas, pero no corresponde con el C4 de contexto: incluye «Universidad» (ausente del C4) y el contexto técnico añade App Flutter y PostgreSQL, que no están en el C4 |
| Entre 3 y 5 escenarios de calidad redactados | `docs/arc42/arc42-template-EN.md:85-93` (5 filas) | Cumple | 5 escenarios (rendimiento, usabilidad, seguridad, disponibilidad, escalabilidad). Desviación de estructura: están en la sección 1; la sección 10 (líneas 404-406) quedó vacía |
| Cada escenario con sus seis partes y medida numérica | `docs/arc42/arc42-template-EN.md:87-93` | No cumple | Tabla de dos columnas sin desglosar fuente/estímulo/artefacto/entorno/respuesta/medida; falta el entorno en varios escenarios y la condición de carga en 4 de 5 medidas («<3 pasos», «100 % endpoints», «99 % mensual» no declaran carga) |
| Árbol de utilidad que prioriza por impacto y riesgo | `docs/arc42/arc42-template-EN.md:57-84` | No cumple | El árbol es una jerarquía plana de atributos sin valores de impacto/riesgo. La priorización 1-8 está en otra tabla (44-53) y no coincide con los escenarios redactados (Usabilidad, prioridad 8, sí está; Portabilidad 5, Mantenibilidad 6 y Privacidad 7 no) |
| C4 de contexto con leyenda y flechas etiquetadas | `docs/c4/context.md` (mermaid, código) | No cumple | Está como código ✓ (ruta `docs/c4/context.md`), pero las flechas no llevan etiqueta y no hay caja de leyenda (solo `classDef` con colores). Además el sistema aparece dos veces: `R` y `ROUTB` como nodos distintos |
| Escenarios alcanzables desde la fila de su aspecto | `docs/aspectos.md` en `14e6688` | No cumple | Una sola fila, sin enlaces a escenarios ni columnas C4/ADR/código/pruebas/evidencia |

**Resultado informado por el autocalificador: 2 de 9 criterios cumplidos en la matriz de la ficha.**

## 3.2 Contraste con el estado actual

| Origen | Hallazgo | Acción realizada | Evidencia actual | Estado |
| :--- | :--- | :--- | :--- | :--- |
| S2 | Objetivos de negocio sin interesado (*stakeholder*) explícito y objetivos específicos redactados como funcionalidades | Se reestructuró la sección asignando a cada objetivo de calidad su interesado concreto en una columna dedicada, y se separaron las funcionalidades en un apartado independiente | `docs/arc42/01_introduccion_y_objetivos.md` (secciones 1.2, 1.4 y 1.5) | Corregido |
| S2 | Restricciones de arquitectura sin categorías organizativas ni legales | Se reorganizaron las restricciones bajo la taxonomía requerida: organizativas, técnicas, de integración, legales/normativas y comerciales/alcance, justificando cada una con «dado que…» | `docs/arc42/02_restricciones_de_arquitectura.md` (secciones 2.1 a 2.5) | Corregido |
| S2 | Discrepancia entre arc42 sección 3 y C4 de contexto (incluía Universidad ausente en C4 y exponía Flutter/PostgreSQL en contexto técnico) | Se armonizaron los contextos empresarial y técnico con el modelo C4 Nivel 1, delimitando a los actores, sistemas externos reales (Mapas y Notificaciones Push) y reservando Flutter y PostgreSQL para el Nivel 2 (Contenedores) | `docs/arc42/03_contexto_y_alcance.md` y `docs/c4/context.md` | Corregido |
| S2 | Desviación estructural: escenarios ubicados en la sección 1 dejando la sección 10 vacía | Se modularizó arc42 en 12 archivos independientes y se trasladaron formalmente los escenarios y el árbol de utilidad a la sección 10 | `docs/arc42/10_requisitos_de_calidad.md` | Corregido |
| S2 | Escenarios sin desglose de sus seis partes ni condición de carga en las medidas numéricas | Se reconstruyó la tabla de escenarios detallando Fuente, Estímulo, Artefacto, Entorno, Respuesta y Medida cuantificada con umbrales y condiciones de carga específicas | `docs/arc42/10_requisitos_de_calidad.md#102-escenarios-de-calidad` | Corregido |
| S2 | Árbol de utilidad plano sin priorización de impacto/riesgo y discrepante con los escenarios redactados | Se diseñó un árbol de utilidad en diagrama Mermaid desglosando los atributos en subatributos y metas concretas alineadas directamente con los escenarios documentados | `docs/arc42/10_requisitos_de_calidad.md#101-resumen-de-los-requisitos-de-calidad--árbol-de-utilidad` | Corregido |
| S2 | Diagrama C4 de contexto con flechas sin etiquetar, sin caja de leyenda y con el sistema duplicado (`R` y `ROUTB`) | Se unificó el sistema en un único nodo (`R`), se etiquetaron todas las flechas con la acción y protocolo de interacción, y se incorporó la tabla de leyenda de elementos | `docs/c4/context.md` (Nivel 1 — Contexto) | Corregido |
| S2 | Escenarios no alcanzables desde la fila de su aspecto en `docs/aspectos.md` | Se incorporaron en la tabla de aspectos enlaces directos hacia los escenarios de calidad correspondientes en la sección 10 de arc42 | `docs/aspectos.md` (columna *Evidencia*) | Corregido |

---

# 4. Semana 3

## 4.1 Matriz de la ficha

| Criterio | Evidencia técnica | Estado | Observaciones |
| :--- | :--- | :--- | :--- |
| arc42 sección 4 con estrategia y tácticas ligadas a los escenarios | `docs/arc42/arc42-template-EN.md:248-268` «Enfoque para alcanzar los objetivos de calidad clave»: tácticas por objetivo priorizado (rendimiento: consultas geoespaciales indexadas ≤2 s; seguridad: hashing con salt + JWT + HTTPS; disponibilidad: backend stateless; usabilidad: flujos ≤3 pasos) | Cumple | Tácticas concretas ligadas a las prioridades del árbol de utilidad, no descripción abstracta del estilo. Matiz: se ligan al objetivo priorizado, no al escenario individual de 10.2 |
| Matriz comparativa de los tres estilos contra el árbol de utilidad | `docs/adr/0001-usar-monolito-modular.md` «Matriz de decisión: capas / hexagonal / monolito modular x los 8 atributos del árbol (rendimiento, seguridad, disponibilidad, escalabilidad, portabilidad, mantenibilidad, privacidad, usabilidad) con Favorece/Neutral/Perjudica y razón | Cumple | Compara contra el árbol del equipo con juicios contextuales (Ley 1581, portabilidad Flutter, cupos). Matiz: por atributo, no por escenario con su medida |
| `docs/adr/0001-*.md` con el nombre de la convención | `docs/adr/0001-usar-monolito-modular.md` (pasa el filtro); título «0001 - Arquitectura de monolito modular para el backend de ROUTB» enuncia la decisión | Cumple | Convención y título correctos |
| ADR con contexto, opciones evaluadas, decisión y consecuencias | Ídem: Contexto, Decisión (con criterios), Alternativas consideradas, Consecuencias (positivas y negativas/riesgos) | Cumple | Consecuencias incluyen riesgos reales (degeneración a «monolito enredado», fallo global) y trazabilidad en tabla |
| Alternativas descartadas con su motivo | Ídem, «Alternativas consideradas»: hexagonal (abstracciones adicionales no necesarias para el alcance) y capas (dificulta trabajo paralelo de 4 integrantes) | Cumple | Motivos específicos del equipo, no genéricos |
| ADR alcanzable desde `docs/aspectos.md` y desde el escenario que lo motiva | `docs/aspectos.md` fila 2 (Organización del backend) → `adr/0001-usar-monolito-modular.md` ✓; `arc42-template-EN.md:388` (S9) y `1255,297` (S4 objetivos) también enlazan. La tabla de escenarios 10.2 no enlaza el ADR | No cumple | El enlace desde `aspectos.md` funciona; falta el segundo: ningún escenario de calidad (10.2) enlaza la decisión que lo motiva (los enlaces de S4 son de objetivo de calidad, no de escenario) |
| Arranque con un solo comando documentado en el README | `README.md`: instalación en 6 pasos separados (clone → cd → venv → activate → pip install) + ejecución en pasos separados (`uvicorn app.main:app --reload`, `pytest`) | No cumple | El comando de arranque existe como paso, pero no hay un solo comando documentado como pide la ficha. Archivos soporte presentes: `backend/requirements.txt`, `backend/app/main.py`. Ejecución: No verificado (regla del kit) |
| Prueba automatizada en verde | `backend/tests/test_health.py:5-10` (`test_health_check` con `TestClient`); sin `.github/workflows/`; sin evidencia de ejecución aportada | No verificado | La prueba existe y es razonable, pero el «verde» no se puede comprobar: no hay run de CI ni URL/captura. Haría falta ejecutar `pytest` (prohibido por regla del kit) o que el equipo aporte el run |
| Estructura de paquetes correspondiente al estilo del ADR | `backend/app/modules/{auth,users,trips,requests,notifications,admin}/` cada uno con `domain/`, `application/`, `adapters/` + `backend/app/shared/` | Cumple | Monolito modular con módulos por dominio y separación interna declarada, coherente con el ADR |

**Resultado informado por el autocalificador: 6 de 9 criterios cumplidos (1 No verificado).**

## 4.2 Contraste con el estado actual

| Origen | Hallazgo | Acción realizada | Evidencia actual | Estado |
| :--- | :--- | :--- | :--- | :--- |
| S3 | Los escenarios de calidad (10.2) no enlazaban el ADR que los motivaba | Se consolidó la trazabilidad bidireccional vinculando los escenarios de calidad y objetivos arquitectónicos con las decisiones tomadas en los ADR | `docs/aspectos.md`, `docs/arc42/09_decisiones_arquitectonicas.md` y `docs/arc42/10_requisitos_de_calidad.md` (hacia ADR 0001, ADR 0002 y ADR 0003) | Corregido |
| S3 | README sin un solo comando documentado para arranque | Se documentaron comandos unificados e independientes de un solo paso para arrancar el backend (`uvicorn app.main:app --reload`) y frontend (`flutter run`) | `README.md` (sección *Ejecución: Arranque del Backend con un solo comando* y *Arranque del Frontend con un solo comando*) | Corregido |
| S3 | Prueba automatizada en verde no comprobable por falta de workflow de CI o evidencia de ejecución | Se implementó el flujo de integración continua en GitHub Actions ejecutando la suite de pruebas (`pytest`) automáticamente y se enlazó el run exitoso en el README | `.github/workflows/ci.yml` y `README.md#prueba-automatizada-del-recorrido-completo-ci` | Corregido |

