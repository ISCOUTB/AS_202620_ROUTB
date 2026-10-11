# ADR 0013: Notificaciones push con Firebase Cloud Messaging (FCM) como canal de aviso

## Estado

Aceptado.

## Contexto

El ADR 0004 estableció la adopción de una arquitectura de integración síncrona REST para comandos y lecturas de estado en ROUTB, descartando inicialmente mecanismos de mensajería asíncrona complejos para evitar sobrecostos operativos.

Sin embargo, en el modelo de transporte compartido puerta a puerta de la Fase 2:
1. La aprobación de una solicitud por parte de un conductor es una acción humana asíncrona por naturaleza (puede ocurrir minutos u horas después de enviada).
2. Sin notificaciones fuera de la aplicación, el pasajero no tiene manera de enterarse oportunamente de la aceptación de su cupo a menos que mantenga la aplicación abierta y realice sondeos continuos por HTTP (polling), lo cual degrada la batería del dispositivo móvil y genera tráfico innecesario en el servidor.
3. El conductor necesita ser alertado inmediatamente cuando un nuevo pasajero solicita cupos en su ruta.

## Decisión

1. **Adopción de FCM como mecanismo de aviso:**
   - Se incorpora Firebase Cloud Messaging (FCM) exclusivamente en dispositivos Android para emitir notificaciones push.
   - **Complemento al ADR 0004:** La notificación push es estrictamente un **aviso de transporte**, nunca la fuente de verdad del sistema.
   - La API REST permanece como el único canal transaccional y de estado. Al recibir una push o al abrirse la aplicación, el cliente Flutter siempre resincroniza su estado llamando a los endpoints REST correspondientes (`GET /requests/me` o `GET /trips/{id}`).

2. **Gestión de tokens en backend:**
   - Se crea la tabla `device_tokens` (`user_id`, `device_token`, `platform`, `created_at`, `last_seen_at`) mediante la migración 007.
   - Los endpoints `PUT /notifications/device-token` y `DELETE /notifications/device-token/{token}` permiten asociar y desvincular el token del dispositivo de la sesión autenticada del usuario.
   - Si FCM reporta un token no registrado (`UNREGISTERED`), el backend lo elimina automáticamente de la base de datos.

3. **Tolerancia a fallos:**
   - El fallo en el envío de una push nunca bloquea ni aborta la transacción REST principal (la creación o aceptación de solicitudes). El envío ocurre después del `commit` y los errores de entrega no interrumpen la respuesta HTTP.

4. **Credenciales y seguridad:**
   - El backend usa `firebase-admin`; la credencial de la cuenta de servicio (`FCM_SERVICE_ACCOUNT_B64`) y el identificador de proyecto (`FCM_PROJECT_ID`) residen únicamente en variables de entorno del servidor.
   - En el cliente Flutter, `google-services.json` está explícitamente excluido del repositorio en `.gitignore`.

## Consecuencias

- Notificación inmediata a pasajeros y conductores sin necesidad de sondeo continuo en segundo plano.
- Conservación de la consistencia transaccional: una falla en la red de Firebase no rompe la lógica de negocio de cupos ni solicitudes.
- Mantenimiento estricto de las reglas de seguridad sin exposición de credenciales privadas en el repositorio.
