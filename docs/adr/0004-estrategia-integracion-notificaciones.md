# 0004 - Estrategia de integración de notificaciones

## Estado

Propuesto

## Contexto

ROUTB necesita notificar a los estudiantes sobre eventos relevantes de sus
viajes, como cambios de estado, solicitudes de reserva y confirmaciones.

La aplicación cliente se desarrolla con Flutter y es responsable de la
presentación de las notificaciones. La gestión de mapas también pertenece al
frontend y no forma parte de este ADR. El backend debe encargarse de
determinar cuándo corresponde enviar una alerta y de integrarse con el
proveedor de mensajería.

Se requiere una integración que no bloquee la operación principal del usuario
si el proveedor externo está lento o temporalmente no disponible.

## Decisión

El backend se integrará con **Firebase Cloud Messaging (FCM)** para el envío de
notificaciones push a los dispositivos registrados.

El envío se realizará mediante un patrón asíncrono basado en eventos o tareas
en segundo plano:

- La operación principal del backend registra el cambio de estado o evento de
  negocio.
- El evento desencadena una tarea de notificación.
- La tarea comunica el mensaje a FCM y registra el resultado del envío.
- Un fallo temporal de FCM no revierte la operación principal del usuario.

Los datos sensibles no se incluirán directamente en el contenido de la
notificación. El cliente recibirá únicamente la información necesaria para
identificar el evento y podrá consultar los datos actualizados mediante la API.

## Alternativas consideradas

### Llamada HTTP síncrona durante la petición

Se descarta porque la petición del usuario quedaría esperando la respuesta de
FCM. Una latencia elevada o una caída del proveedor podría aumentar el tiempo
de respuesta o impedir que se complete una acción válida, como reservar o
cancelar un cupo.

### Envío directo desde Flutter

Se descarta porque expondría en el cliente responsabilidades y credenciales
que deben permanecer en el backend. También dificultaría centralizar las
reglas que determinan qué eventos generan notificaciones.

### Proveedor de notificaciones distinto de FCM

Se descarta inicialmente porque FCM ofrece integración directa con Flutter,
soporte para Android e iOS y una solución adecuada para el alcance actual del
proyecto. La decisión podrá revisarse si cambian los requisitos de plataforma
o de entrega.

## Consecuencias

### Positivas

- Las operaciones principales no dependen de la disponibilidad inmediata de
  FCM.
- El backend mantiene el control de las reglas de negocio y de las
  credenciales del proveedor.
- Flutter puede recibir notificaciones push de forma nativa mediante FCM.
- El mecanismo permite incorporar reintentos y observabilidad del estado de
  cada envío.

### Negativas y riesgos

- Se requiere administrar tokens de dispositivos y su ciclo de vida.
- El procesamiento asíncrono introduce consistencia eventual entre el evento
  de negocio y la llegada de la notificación.
- Será necesario definir una estrategia de reintentos, expiración y registro de
  errores.
- La integración añade una dependencia externa y requiere configurar Firebase
  por ambiente.