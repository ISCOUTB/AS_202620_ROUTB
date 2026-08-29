# Aspectos del proyecto

Cada aspecto se enlaza con el escenario de calidad que lo motiva ([arc42-template-EN.md](arc42/arc42-template-EN.md)) y con su evidencia de arquitectura.

| ID | Aspecto | Requisito | C4 | ADR | Código | Pruebas | Evidencia |
|---|---|---|---|---|---|---|---|
| 1 | Gestión de disponibilidad de cupos | El sistema debe permitir a los estudiantes consultar la cantidad de cupos disponibles en los viajes publicados por los conductores. | [Contexto C4](c4/context.md) |  |  |  | [Rendimiento](arc42/arc42-template-EN.md#objetivos-de-calidad) |
| 2 | Organización del backend | El backend se estructura como un monolito modular, dividido internamente en módulos independientes por funcionalidad, para facilitar el mantenimiento y el trabajo paralelo del equipo. | [Contexto C4](c4/context.md) | [ADR 0001 - Arquitectura de monolito modular](adr/0001-usar-monolito-modular.md) | [Backend](../backend/app) | [Test](../backend/tests) | [Mantenibilidad](arc42/arc42-template-EN.md#objetivos-de-calidad) |
| 3 | Autenticación y protección de datos | Todo endpoint sensible valida identidad mediante JWT y los datos personales se tratan conforme a la Ley 1581 de 2012. | [Contexto C4](c4/context.md) |  |  |  | [Seguridad](arc42/arc42-template-EN.md#objetivos-de-calidad); [Privacidad](arc42/arc42-template-EN.md#objetivos-de-calidad); [Restricciones legales](arc42/arc42-template-EN.md#restricciones-legales-y-normativas) |
