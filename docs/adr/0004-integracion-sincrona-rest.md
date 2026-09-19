# 0004 - Integración síncrona mediante REST/JSON entre cliente y backend

## Estado

Aceptado

## Contexto

ROUTB necesita que el estudiante pasajero sepa de inmediato si consiguió un cupo en un recorrido. Cuando el pasajero pulsa "Reservar", el sistema debe responder con una confirmación o un rechazo antes de que la pantalla cambie. Esta necesidad de respuesta inmediata define cómo los componentes del sistema deben comunicarse entre sí.

El escenario de calidad concreto es el control de cupos: si dos pasajeros intentan reservar el último cupo al mismo tiempo, uno debe recibir confirmación y el otro debe recibir rechazo, sin que ninguno quede en espera indefinida ni sin respuesta. Esto se midió con 20 intentos concurrentes sobre un recorrido con 4 cupos, exigiendo que exactamente 4 resulten exitosos y que el percentil 95 de respuesta no supere 3,99 segundos.

## Decisión

La comunicación entre la aplicación móvil y el backend de ROUTB, y entre el backend y sus servicios externos, se realiza de forma **síncrona mediante REST/JSON sobre HTTPS**.

Cada solicitud espera su respuesta antes de continuar. El cliente sabe en el mismo momento si la operación fue exitosa o fallida, sin necesidad de consultar un estado posterior.

## Alternativa descartada: integración asíncrona por eventos

Se consideró un modelo en el que el cliente envía una solicitud de reserva y el backend la encola para procesarla después, notificando al pasajero mediante un mensaje push cuando el resultado esté disponible.

**Motivo de descarte:**

- Introduce acoplamiento con un servicio de colas o mensajería que no existe en la infraestructura actual del proyecto.
- El pasajero no sabría si consiguió el cupo hasta recibir la notificación, lo que impide la navegación inmediata a la pantalla de confirmación.
- Si la notificación push falla o se retrasa, el flujo queda incompleto sin forma de recuperarlo en el cliente.
- Para el escenario de cupos concurrentes, el modelo asíncrono añade complejidad sin mejorar la consistencia, que ya está garantizada por la actualización atómica en base de datos.

## Consecuencias

**Positivas:**

- La respuesta llega en la misma conexión HTTP: el cliente puede actuar sobre ella sin lógica de espera o consulta posterior.
- La prueba de concurrencia es directa: se miden las respuestas de los 20 intentos y se verifican los 4 exitosos en la misma ejecución.
- No se introduce ningún componente adicional de mensajería o colas.

**Negativas / riesgos:**

- Si el backend tarda en responder, el cliente queda bloqueado hasta recibir la respuesta o agotar el tiempo de espera.
- Las notificaciones secundarias (avisos de cambios de estado a otros pasajeros) siguen siendo asíncronas mediante el servicio de push externo, pero no afectan al flujo principal de reserva.

## Trazabilidad

| Elemento | Referencia |
|---|---|
| Escenario de calidad de cupos | [arc42 sección 10](../arc42/10_requisitos_de_calidad.md) |
| Control atómico de reservas | [ADR 0003](0003-control-atomico-de-cupos.md) |
| Protocolo REST/JSON en flechas del C4 | [C4 Nivel 2](../c4/context.md) |
| Prueba de concurrencia | `backend/tests/test_cupos.py` |
