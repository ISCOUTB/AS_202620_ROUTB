# 11. Riesgos y deuda técnica

Esta sección registra las situaciones que pueden afectar la calidad, la
operación o la evolución de ROUTB. Se distingue entre **riesgos del sistema**,
que pueden ocurrir si determinadas condiciones se presentan, y **deuda
técnica**, que corresponde a simplificaciones, decisiones pendientes o
limitaciones conocidas que trasladan trabajo y posibles costos al futuro.

## 11.1 Riesgos del sistema

Los siguientes riesgos pueden afectar el funcionamiento, la seguridad, la
adopción y la evolución de ROUTB.

| Riesgo | Impacto | Probabilidad | Mitigación |
|---|---|---:|---|
| Baja adopción por parte de estudiantes conductores y pasajeros. | La plataforma tendría poca utilidad si no existe una oferta suficiente de recorridos y solicitudes. | Media | Validar los flujos con usuarios reales, priorizar la facilidad de uso y promover el uso dentro de la comunidad universitaria. |
| Información incompleta o desactualizada sobre recorridos, horarios y cupos. | Los usuarios podrían tomar decisiones incorrectas o perder confianza en la plataforma. | Media | Permitir actualizar y cancelar recorridos, mostrar el estado de las solicitudes y establecer reglas claras de vigencia. |
| Una operación de reserva no controla correctamente la concurrencia. | Dos pasajeros podrían obtener el mismo cupo o la disponibilidad podría quedar inconsistente. | Media | Descuento atómico con `UPDATE … WHERE available_seats >= seat_count` dentro de la transacción de aceptación (ADR 0003) y pruebas de concurrencia del flujo real (ADR 0021). |
| Se expone información personal o se permite acceso a una operación sin autorización. | Afectación de la privacidad de los estudiantes y posible incumplimiento normativo. | Media | Aplicar autenticación, autorización, comunicaciones seguras y controles de acceso según el tipo de usuario. |
| Un proveedor externo de mapas o notificaciones deja de estar disponible. | Algunas funcionalidades podrían degradarse o no completarse. | Media | Aislar las integraciones, controlar los errores y comunicar al usuario la indisponibilidad de forma controlada. |
| Un proveedor externo responde lento (sin error explícito). | La latencia se suma al p95 y puede romper el umbral de 3,99 s. | Media | Timeout único `ROUTING_TIMEOUT_SECONDS` (1,4 s), respaldo geodésico/`503` tipado y no persistir degradados (ADR 0014). |
| El crecimiento de usuarios, recorridos y solicitudes supera la capacidad prevista. | Aumento de los tiempos de respuesta o indisponibilidad durante las horas de mayor demanda. | Media | Medir el rendimiento, optimizar las operaciones críticas y ampliar la capacidad cuando sea necesario. |
| Un fallo del almacenamiento o del servidor interrumpe el servicio. | Pérdida temporal de disponibilidad o de información. | Baja/Media | Definir respaldos, procedimientos de recuperación y mecanismos de redundancia según el crecimiento del sistema. |
| Modo de fallo integración: El servidor no responde (caída o mantenimiento del backend en Dokploy, o corte de red del dispositivo). | El estudiante no puede iniciar sesión, consultar recorridos ni enviar solicitudes de cupo; llamadas bloqueadas. | Media | Timeout de 35 s en `frontend/lib/core/network/api_client.dart:26, 139`, captura de `SocketException`/`TimeoutException` (`api_client.dart:140-145`) y botón de reintento manual interactivo en la interfaz (`frontend/lib/features/passenger/screens/passenger_screen.dart:371-374`). |
| Modo de fallo integración: El servidor responde tarde (congestión del backend o de la base de datos, o red móvil lenta). | El cliente agota el tiempo de espera si es estricto, o el usuario genera peticiones concurrentes por frustración. | Alta | Margen de 35 s en `api_client.dart:26`, bloqueo del botón de reserva mientras hay un envío en curso (`passenger_screen.dart:736`) y manejo unificado con `ApiException` amigable. |
| Modo de fallo integración: La petición se envía o procesa dos veces (doble clic o reintento de la app tras corte de red). | Riesgo de duplicar solicitudes de cupos para un mismo estudiante en un mismo viaje o sobreventa de capacidad. | Media | Índice único parcial `uq_trip_requests_active_passenger` sobre solicitudes activas (migración 010, ADR 0021); `create_request` traduce el conflicto a `ActiveRequestAlreadyExistsError` (400). Las transiciones de aceptar/rechazar son condicionales e idempotentes y releen el estado si otra operación gana la carrera (`manage_request.py`). |

## 11.2 Deuda técnica

La deuda técnica se documenta para hacer explícito qué se acepta
temporalmente durante el desarrollo del proyecto y bajo qué condición debería
revisarse. No toda deuda debe eliminarse de inmediato; debe priorizarse según
su impacto en la seguridad, la consistencia de los datos y la capacidad de
evolución.

### Deuda técnica identificada

| Deuda técnica | Impacto | Estado | Tratamiento |
|---|---|---|---|
| Cobertura funcional desigual entre módulos. | Puede generar comportamientos inconsistentes y dificultar la validación integral de los flujos. | Actual | Completar y probar progresivamente los módulos priorizando autenticación, recorridos y solicitudes. |
| Despliegue y configuración dependientes de pasos manuales. | Aumenta los errores entre ambientes y dificulta reproducir la operación. | Actual | Documentar los ambientes y automatizar gradualmente la preparación y publicación. |
| Estrategia de respaldo y recuperación no definida en detalle. | Un incidente podría causar pérdida o indisponibilidad de información. | Actual | Definir frecuencia, retención, responsables y procedimiento de restauración. |
| Dependencia de una infraestructura inicial pequeña. | El crecimiento puede exigir cambios urgentes de capacidad y operación. | Futura | Revisar la infraestructura con base en métricas reales de uso y rendimiento. |
| Sin reintentos automáticos ante proveedores externos. | Una caída transitoria breve se responde como degradada en vez de reintentarse. | Actual | Aceptado por ADR 0014 para no multiplicar la latencia; revisar si el p95 lo permite. |
| Ausencia de clave de idempotencia (`Idempotency-Key`) en peticiones mutantes HTTP del backend. | Ante un timeout de respuesta con procesamiento exitoso en servidor, un reintento del cliente provoca rechazo o inconsistencia en lugar de retornar la respuesta original en caché. | Actual | Incorporar middleware de idempotencia en FastAPI que registre el UUID v4 de la cabecera `Idempotency-Key` en caché o tabla temporal por 60 segundos (Plan: Q1 2027). |
| Ausencia de reintentos automáticos con retroceso exponencial (*exponential backoff*) y *jitter* en `ApiClient`. | Los errores transitorios de red exigen intervención manual obligatoria del estudiante mediante el botón de reintento en UI. | Actual | Implementar política de reintentos automáticos en el cliente HTTP para peticiones de solo lectura (GET) con 3 intentos máximos y retroceso aleatorio (Plan: Q1 2027). |
| Ausencia de patrón *Circuit Breaker* en el cliente móvil Flutter. | Durante caídas prolongadas del backend o de Supabase, la app continúa enviando tráfico inútil y agotando la batería y la red del usuario. | Actual | Diseñar interceptor de circuito en `ApiClient` con umbral de corte tras 5 fallos consecutivos y 30 segundos de enfriamiento antes de reintentar (Plan: Q2 2027). |

### Deuda técnica aceptada y deuda a evitar

Algunas decisiones se mantienen deliberadamente simples por el alcance
académico de ROUTB. Se acepta evolucionar la infraestructura, el monitoreo y
la separación de componentes cuando existan evidencias de que el volumen de
usuarios, las integraciones o los requisitos de disponibilidad lo justifican.

La deuda debe revisarse periódicamente. Antes de realizar cambios costosos se
deben recopilar evidencias de rendimiento, disponibilidad, errores, uso de los
servicios externos y crecimiento de los datos.

No se debe aceptar como deuda permanente:

- almacenar credenciales o información sensible de forma insegura;
- omitir controles de autorización;
- permitir inconsistencias en cupos y solicitudes;
- ocultar errores de integraciones externas;
- ignorar respaldos y recuperación de la información.

Estas situaciones afectan directamente la seguridad, la privacidad y la
consistencia del sistema, por lo que deben tratarse como defectos prioritarios
y no como simplificaciones del alcance.

---
