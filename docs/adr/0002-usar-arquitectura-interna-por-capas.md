# 0002 - Arquitectura interna por capas para los módulos del backend de ROUTB

## Estado

Aceptado

## Contexto

En el [ADR 0001](0001-usar-monolito-modular.md), se definió que el backend de ROUTB utilizará una macroarquitectura de **Monolito Modular**. Como siguiente paso, era necesario definir la microarquitectura o diseño interno que tendrán los módulos para organizar su código fuente.

El código actual ya refleja una separación de responsabilidades técnica dentro de cada módulo, apoyándose fuertemente en las herramientas y el ecosistema del framework FastAPI. Se requería oficializar esta decisión arquitectónica frente a otras alternativas más complejas (como la Arquitectura Hexagonal), evaluando el impacto en la velocidad del equipo y la curva de aprendizaje.

## Decisión

Para la estructura interna de los módulos de ROUTB se utilizará una **Arquitectura por Capas**. 

Cada módulo dividirá sus responsabilidades en los siguientes archivos estándar:
- **`router.py` (Capa de Presentación/API):** Define los endpoints y recibe las peticiones HTTP.
- **`schemas.py` (Capa de Validación):** Define los modelos Pydantic para validar datos de entrada/salida.
- **`service.py` (Capa de Lógica de Negocio):** Contiene las reglas de negocio y orquesta las operaciones.
- **`models.py` (Capa de Persistencia):** Define las entidades del ORM mapeadas a la base de datos PostgreSQL.

Se elige este enfoque porque:
- Es el patrón de diseño más natural y estándar al trabajar con FastAPI.
- Prioriza la velocidad de desarrollo, permitiendo al equipo implementar funcionalidades rápidamente sin tener que escribir abstracciones o interfaces innecesarias.
- Tiene una curva de aprendizaje muy baja, ya que el equipo ya domina la separación de controladores, servicios y modelos.
- Evita la sobreingeniería en una etapa académica del proyecto donde el enfoque principal es entregar valor funcional de forma iterativa.

## Alternativas consideradas

### Arquitectura Hexagonal (Puertos y Adaptadores)

- **Ventajas:** Aísla completamente la lógica de negocio (dominio) del framework web (FastAPI) y de la base de datos (PostgreSQL). Facilita las pruebas unitarias puras y protege el sistema contra cambios tecnológicos futuros.
- **Desventajas:** Exige una alta inversión de tiempo inicial para definir puertos (interfaces) y adaptadores. Añade una complejidad innecesaria para un CRUD o flujos de negocio sencillos, y tiende a "pelear" con la validación nativa que ofrece FastAPI a través de Pydantic.
- **Motivo de descarte:** La complejidad y la curva de aprendizaje (conceptos estrictos de DDD e Inversión de Dependencias) ralentizarían significativamente al equipo, lo cual representa un riesgo inaceptable para los tiempos de entrega del semestre. 

## Consecuencias de la Arquitectura por Capas

**Positivas:**
- Desarrollo ágil: los desarrolladores saben exactamente dónde va cada fragmento de código (rutas, validaciones, lógica o BD).
- Integración perfecta con FastAPI y herramientas de autogeneración de documentación (Swagger/OpenAPI).
- Facilita la lectura del proyecto para cualquier desarrollador externo con experiencia básica en desarrollo web.

**Negativas / riesgos:**
- Existe el riesgo de que la capa de lógica de negocio (`service.py`) se acople fuertemente a los modelos del ORM (`models.py`) o a los esquemas de FastAPI (`schemas.py`). 
- Si en el futuro se decide cambiar el framework (ej. pasar de FastAPI a Django), el costo de refactorización será mayor que si se hubiera usado una Arquitectura Hexagonal. Este riesgo se asume como aceptable dado el alcance actual.

## Trazabilidad

| Aspecto / Requisito | Elementos C4 relevantes | Artefactos / documentación | Pruebas / evidencia existente |
|---|---|---|---|
| Microarquitectura interna de los módulos | Componentes internos de cada módulo en el contenedor API Backend | [Backend](../arc42/05_vista_de_bloques_de_construccion.md) | Estructura de archivos (`router.py`, `service.py`, `models.py`, `schemas.py`) en `backend/app/modules/` |
| Velocidad de desarrollo y mantenibilidad | API Backend | Matriz de decisión (abajo) | Entregas funcionales de los flujos de autenticación y vistas en tiempo esperado. |

---

## Matriz de decisión

Comparación de la microarquitectura interna para los módulos del monolito.

| Criterio | Arquitectura por Capas (Adoptada) | Arquitectura Hexagonal (Descartada) |
|---|---|---|
| **Velocidad de Desarrollo** | **Alta:** Implementación directa sin interfaces intermedias. | **Baja:** Requiere escribir múltiples abstracciones para una sola funcionalidad. |
| **Curva de Aprendizaje** | **Baja:** El equipo ya conoce el patrón (similar al clásico MVC). | **Alta:** Exige dominar Inversión de Dependencias y diseño agnóstico. |
| **Alineación con FastAPI** | **Alta:** Integración natural con dependencias y esquemas de Pydantic. | **Baja/Media:** FastAPI está diseñado para resolver cosas en la capa web que la Hexagonal intenta alejar. |
| **Aislamiento del Dominio** | **Medio:** La lógica de negocio (`service.py`) interactúa directamente con el ORM. | **Alto:** Lógica de negocio 100% aislada e independiente de tecnologías externas. |

**Resultado:** Se selecciona la Arquitectura por Capas ya que el beneficio de la velocidad de desarrollo y la baja fricción con FastAPI supera con creces la necesidad de un aislamiento puro del dominio para las condiciones y el tamaño del equipo actual.