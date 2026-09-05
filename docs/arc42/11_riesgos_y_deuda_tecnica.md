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
| Una operación de reserva no controla correctamente la concurrencia. | Dos pasajeros podrían obtener el mismo cupo o la disponibilidad podría quedar inconsistente. | Media | Validar la disponibilidad dentro de una transacción y definir reglas claras para aceptar o rechazar solicitudes. |
| Se expone información personal o se permite acceso a una operación sin autorización. | Afectación de la privacidad de los estudiantes y posible incumplimiento normativo. | Media | Aplicar autenticación, autorización, comunicaciones seguras y controles de acceso según el tipo de usuario. |
| Un proveedor externo de mapas o notificaciones deja de estar disponible. | Algunas funcionalidades podrían degradarse o no completarse. | Media | Aislar las integraciones, controlar los errores y comunicar al usuario la indisponibilidad de forma controlada. |
| El crecimiento de usuarios, recorridos y solicitudes supera la capacidad prevista. | Aumento de los tiempos de respuesta o indisponibilidad durante las horas de mayor demanda. | Media | Medir el rendimiento, optimizar las operaciones críticas y ampliar la capacidad cuando sea necesario. |
| Un fallo del almacenamiento o del servidor interrumpe el servicio. | Pérdida temporal de disponibilidad o de información. | Baja/Media | Definir respaldos, procedimientos de recuperación y mecanismos de redundancia según el crecimiento del sistema. |

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
