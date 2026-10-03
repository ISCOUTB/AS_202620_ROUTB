# ADR 0007: Solicitud grupal de cupos

## Estado

Aceptado por el equipo para la Porción de la semana 9.

## Contexto

El flujo actual representa una solicitud con un solo cupo. El equipo necesita una opción para que un pasajero solicite cupos para sí mismo y acompañantes que no tienen cuenta en ROUTB. La disponibilidad pertenece a `trips`; la solicitud y la cantidad pedida pertenecen a `requests`.

## Decisión

Una solicitud representa al pasajero titular y a su grupo. Puede incluir entre **1 y 4 cupos** (el titular y hasta tres acompañantes). El conductor acepta o rechaza el grupo completo. La aceptación descuenta la cantidad solicitada de forma atómica; si la capacidad ya no alcanza, no se acepta parcialmente. Si el pasajero retira una solicitud aceptada, se liberan todos sus cupos una sola vez. Las solicitudes existentes y los clientes que omiten la cantidad conservan el comportamiento de un cupo.

Los acompañantes no necesitan cuenta y ROUTB no almacena sus nombres ni otros datos personales. El pasajero que crea la solicitud es el responsable de coordinar el grupo.

`requests` persiste la solicitud y su cantidad. `trips` expone operaciones públicas de aplicación para consultar el contexto de un viaje y reservar o liberar cupos mediante actualizaciones condicionales atómicas. La coordinación de estado y disponibilidad se confirma en una transacción; ningún caso de uso de `requests` modifica el ORM de `trips` directamente.

## Alternativas consideradas

### Una solicitud por cada acompañante

Se descarta: exigiría cuentas e identidades para personas que pueden no usar ROUTB y cambia el alcance a invitaciones o registro de grupo.

### Crear un tipo de cuenta temporal o invitar acompañantes

Se descarta por el alcance de la Porción y porque introduce gestión de identidad y datos personales que no son necesarios para reservar cupos.

### Permitir cupos ilimitados o reservas parciales

Se descarta: el máximo de cuatro se ajusta a la capacidad definida en el producto y una aceptación parcial no comunica con claridad qué integrantes tienen lugar.

### Mantener la solicitud de un solo cupo

Se descarta porque no permite al pasajero coordinar una reserva para su grupo en una sola decisión del conductor.

## Argumentos del equipo

- La decisión funcional fue confirmada por el equipo: máximo cuatro personas contando al pasajero titular, aceptación/rechazo del grupo completo y liberación de todos los cupos al cancelar la reserva.
- Mantener un único pasajero titular conserva el modelo de identidad actual y evita recopilar datos de acompañantes sin cuenta.
- La reserva de todos los cupos en una sola operación y transacción conserva la regla de no sobreventa establecida en el ADR 0003.
- Se mantiene el valor predeterminado de 1 para no romper clientes existentes.
- El criterio de dependencia nueva queda fuera del alcance de esta Porción por acuerdo; no se añade paquete.

## Consecuencias

### Positivas

- Un pasajero puede gestionar un grupo de hasta cuatro personas con una solicitud.
- El conductor toma una única decisión sobre el grupo.
- Aceptación y cancelación conservan la disponibilidad sin asignaciones parciales ni liberaciones duplicadas.
- La API y la app muestran cuántos cupos contiene cada solicitud.

### Costos y límites

- La solicitud identifica al titular, no a cada acompañante; ROUTB no permite seguimiento individual de ellos.
- Las solicitudes pendientes no reservan cupos. El conductor podría recibir un conflicto si otras aceptaciones consumen capacidad antes de responder; deberá aceptar el grupo completo o rechazarlo.
- El contrato OpenAPI recibe un campo opcional y agrega el número de cupos a las respuestas; se publica como versión 0.3.0.

## Verificación

- [Pruebas de solicitudes grupales](../../backend/tests/test_requests_flow.py): cantidades 1–4, validación, aceptación completa, capacidad insuficiente, cancelación y concurrencia.
- [Pruebas de consistencia de cupos](../../backend/tests/test_cupos.py): se conserva el escenario de 20 intentos frente a 4 cupos.
- [Auditoría modular semana 9](../evidencia/auditoria-erosion-semana9.md).
- [Trazabilidad del aspecto](../aspectos.md).
