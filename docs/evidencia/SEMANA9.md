# Documentación del avance — Semana 9

## Resumen ejecutivo

Durante la Semana 9 se entregó una porción funcional real del sistema: la reserva grupal de cupos en ROUTB. El alcance aprobado por el equipo define que un pasajero puede reservar entre 1 y 4 cupos, incluyendo el suyo propio; que el máximo de acompañantes sin cuenta es de 3; que la solicitud se acepta o rechaza como un bloque completo; y que, al cancelar la reserva, se liberan todos los cupos reservados.

La porción se validó con pruebas de aceptación, cancelación, capacidad insuficiente y concurrencia; con medición de rendimiento; con auditoría de erosión modular; y con verificación de dependencias y credenciales. La decisión quedó documentada en el ADR correspondiente y se mantuvo fuera del alcance la integración de un componente generativo en runtime.

## 1. Porción entregada

- **Funcionalidad:** reservas grupales de cupos en ROUTB.
- **Regla de negocio aprobada:** un pasajero puede reservar de 1 a 4 personas en total, incluido él mismo; por lo tanto, el máximo de acompañantes sin cuenta es de 3.
- **Comportamiento:** la solicitud del grupo se acepta o rechaza como una única decisión; al cancelar la reserva se liberan todos los cupos reservados.
- **Implementación técnica:** la disponibilidad se controla de forma atómica mediante operaciones públicas del módulo `trips`, evitando mutaciones directas del ORM desde otros módulos.
- **Compatibilidad:** la API y la app móvil exponen la cantidad de cupos solicitados sin romper la compatibilidad anterior.

## 2. Evidencia de trazabilidad con la arquitectura y el aspecto

- **Fila de `docs/aspectos.md`:** la reserva grupal de cupos queda registrada como un aspecto de la semana, enlazada con su ADR, con el módulo dueño (`trips`) y con la evidencia de pruebas y medición que la respalda.
- **ADR 0007 — Reserva grupal de cupos:** documenta la decisión del equipo sobre la regla de negocio, los límites operativos y la forma de manejar la aceptación, el rechazo y la cancelación del grupo.
- **ADR 0003 — Control atómico de cupos:** sirve como base técnica para la validación de concurrencia y sobreventa, y confirma la decisión de usar operaciones atómicas para la disponibilidad.
- **Arquitectura:** se actualizó el contexto C4 y la documentación del backend para reflejar el flujo de solicitudes grupales y la responsabilidad de cada módulo.

## 3. Prueba de defecto y validación funcional

La evidencia incorpora pruebas que cubren el defecto funcional perseguido y sus efectos de negocio.

- **Casos cubiertos:**
  - aceptación de una solicitud grupal válida,
  - cancelación de la reserva grupal,
  - rechazo por capacidad insuficiente,
  - concurrencia y sobreventa.
- **Objetivo de la prueba crítica:** garantizar que dos solicitudes simultáneas no puedan reservar más cupos de los disponibles.
- **Validación del contrato:** además, se ejecutan pruebas del contrato OpenAPI para detectar cambios incompatibles en la API, de modo que la evolución del sistema no rompa el protocolo público.

La evidencia de regresión demuestra que la porción cumple el alcance definido y que el sistema conserva el comportamiento esperado ante condiciones concurrentes y de capacidad reducida.

## 4. Medición del escenario asociado

Se midió el rendimiento del flujo de reserva grupal y se comparó con la línea base. La medición confirma que el escenario mantiene un tiempo de respuesta dentro del umbral de calidad del proyecto.

- **Criterio de validación:** el escenario no debe degradar la operación ni romper la calidad de servicio esperada por el sistema.
- **Resultado:** la medición reportada para la Semana 9 se mantiene por debajo del umbral exigido, y la evidencia de regresión sugiere que la mejora funcional no introduce un deterioro significativo en el rendimiento.

## 5. Registro de uso de IA

El extracto de `docs/ia.md` deja claro que la IA se usó como apoyo durante el desarrollo, pero no como autoridad técnica ni como ejecutora automática de decisiones de negocio. La cadena de evidencias separa claramente:

- **Lo aceptado:** las propuestas que coincidían con los requisitos de la porción y con la arquitectura existente.
- **Lo corregido:** los puntos que requerían ajuste por alcance, límite de negocio o compatibilidad.
- **Lo rechazado:** lo que no encajaba con la estrategia del equipo, la arquitectura o las restricciones del proyecto.

En particular:

- la regla de cupos fue definida por el equipo,
- la atomicidad de la disponibilidad fue validada por la arquitectura,
- los límites entre módulos fueron revisados por el equipo,
- la IA no toma decisiones de negocio ni se integra al runtime en producción.

## 6. Auditoría de erosión modular

La auditoría de erosión modular verificó que el diseño del sistema no se degradara durante la porción.

### Hallazgos revisados y corregidos

- `requests` no debe consultar ni mutar directamente el ORM `Trip` al crear, aceptar, rechazar o retirar solicitudes.
- `requests` ahora consume los contratos públicos de `trips.application` para leer contexto y aplicar reserva/liberación atómicas.
- El router de `trips` ya no importa helpers privados del router de `requests`; cada módulo arma su propia respuesta de forma explícita y desacoplada.
- `auth` ya no accede directamente al ORM de `users` para iniciar sesión o resolver el usuario del token; la autenticación usa servicios públicos y DTOs del módulo de usuarios.
- Se eliminó una dependencia potencialmente circular entre `users` y `auth`, moviendo la lógica de hash y verificación a un punto compartido.
- Se dejó actualizada la documentación de propiedad de datos para distinguir entre evidencia histórica y estado actual del sistema.

### Límite aceptado

La entidad `TripRequest` conserva una relación de navegación con `Trip` para composiciones de lectura, pero la escritura de disponibilidad se hace desde el módulo dueño (`trips`), no desde `requests`. Esto permite mantener la separación de responsabilidades sin eliminar la capacidad operativa del sistema.

## 7. Verificación de dependencias, credenciales y alcance

Se verificó que la porción no introdujo dependencias ajenas al alcance del proyecto ni elementos críticos de configuración.

- **Dependencias:** no se añadieron paquetes nuevos fuera del alcance de la porción; la solución reutiliza el stack ya definido.
- **Credenciales:** se revisó que no exista información sensible en el código ni en ejemplos de configuración.
- **Alcance:** se descartó la incorporación de IA generativa en runtime y no se creó ningún flujo de extracción de datos de acompañantes ni de cuentas adicionales.

## 8. Decisión sobre el componente generativo

Se decidió no incorporar un componente generativo a ROUTB para esta porción ni como parte del runtime del producto. La razón principal es que el problema de negocio no requiere inferencia generativa en tiempo de ejecución, y la decisión fue reforzada por la necesidad de mantener la arquitectura del sistema simple, trazable y controlada.

La IA se utilizó únicamente como apoyo para análisis, documentación, revisión y exploración de alternativas; las decisiones finales de alcance y arquitectura fueron del equipo y fueron validadas con pruebas, medición y auditoría.

## 9. Conclusión

La Semana 9 entregó una porción real del sistema con evidencia completa: decisión arquitectónica, validación funcional, medición, revisión modular y documentación de uso de IA. El conjunto confirma que la reserva grupal de cupos cumple con el alcance aprobado, mantiene la continuidad del diseño modular y no introduce regresiones relevantes en la disponibilidad ni en la operatividad del servicio.