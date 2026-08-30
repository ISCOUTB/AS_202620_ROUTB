# 2. Restricciones de arquitectura

Las restricciones se agrupan en categorías organizativas, técnicas, de integración, legales/normativas y comerciales/de alcance. Cada una indica explícitamente su justificación («dado que…»).

## 2.1 Restricciones organizativas

- El equipo de desarrollo está compuesto por 4 integrantes, dado que
  es el tamaño fijado para el proyecto académico, lo que condiciona
  la cantidad de trabajo paralelo posible y favorece una arquitectura
  con módulos claramente separables (ver ADR 0001).
- El desarrollo debe ajustarse al cronograma académico del semestre,
  con entregas incrementales por semana, dado que esto limita el
  alcance funcional que el equipo puede completar en el tiempo
  disponible y obliga a priorizar una arquitectura simple sobre
  una más compleja.

## 2.2 Restricciones técnicas

- Uso de Flutter para la aplicación móvil, dado que permite
  cubrir Android e iOS con una sola base de código y se
  ajusta al tiempo y recursos limitados del equipo.
- Uso de FastAPI/Python para el backend, dado que es un framework
  ligero y rápido de implementar, acorde con la experiencia
  del equipo y el tiempo disponible en el semestre.
- Uso de una base de datos relacional, dado que la información
  del dominio (usuarios, recorridos, cupos, solicitudes) tiene
  relaciones claras entre sí que se ajustan bien a este modelo.
- Uso de JWT para la autenticación de sesiones, dado que es un
  estándar para autenticación sin estado en APIs REST, lo que
  facilita la escalabilidad del backend.

## 2.3 Restricciones de integración

- Integración con un proveedor externo de mapas y
  geolocalización, dado que el equipo no cuenta con los recursos
  para desarrollar un motor de mapas propio.
- Integración con un servicio de notificaciones push, dado que
  es necesario informar a los usuarios sobre cambios en sus
  recorridos o solicitudes sin depender de que tengan la app abierta.

## 2.4 Restricciones legales y normativas

- Los datos personales de los estudiantes deben tratarse conforme
  a la Ley 1581 de 2012 (Colombia) y las políticas de protección
  de datos aplicables, dado que el sistema almacena y procesa
  información identificable de estudiantes.
- ROUTB no gestiona pagos ni transacciones comerciales, dado que
  asumir ese rol implicaría cumplir la regulación financiera y de
  medios de pago aplicable, lo cual excede el alcance de un
  proyecto académico.
- La verificación de antecedentes o idoneidad de los conductores
  está fuera del alcance del sistema, dado que implicaría acceso a
  bases de datos oficiales y procesos legales que exceden las
  posibilidades de un proyecto académico.

## 2.5 Restricciones comerciales y de alcance

- ROUTB no actúa como operador de transporte, dado que los
  conductores son estudiantes que comparten su propio vehículo
  y no una flota contratada por la plataforma.
- El transporte compartido se basa en acuerdos informales entre
  estudiantes, dado que no existe una relación comercial regulada
  entre las partes ni participación de la plataforma en el cobro
  del servicio.
