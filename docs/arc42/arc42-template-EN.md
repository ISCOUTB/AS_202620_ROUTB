---
date: Agosto 2026
title: "ROUTB"
---

# 

**About arc42**

arc42, the template for documentation of software and system
architecture.

Template Version 9.0-EN. (based upon AsciiDoc version), July 2025

Created, maintained and © by Dr. Peter Hruschka, Dr. Gernot Starke and
contributors. See <https://arc42.org>.

# Introducción y objetivos

ROUTB es una plataforma diseñada para facilitar y gestionar el transporte compartido entre los estudiantes de la Universidad Tecnológica de Bolívar. El sistema busca centralizar la información relacionada con estudiantes conductores, rutas disponibles y cupos libres, permitiendo a los estudiantes consultar las opciones de transporte y reservar un cupo antes del viaje.

La plataforma surge como respuesta a las dificultades que presentan algunos estudiantes para encontrar y coordinar transporte hacia o desde la universidad, especialmente debido a la falta de información sobre conductores disponibles, cupos y horarios de salida.

## Objetivo general

Desarrollar una plataforma que permita gestionar y coordinar el transporte compartido entre estudiantes de la Universidad Tecnológica de Bolívar.

## Objetivos específicos
- Consultar conductores disponibles.
- Mostrar las rutas de transporte disponibles.
- Visualizar la cantidad de cupos libres.
- Permitir la reserva de un cupo antes del viaje.
- Reducir los tiempos de espera de los estudiantes.
- Mejorar la organización y coordinación de los viajes compartidos.

## Descripción general de los requisitos

ROUTB es una plataforma de movilidad colaborativa dirigida a estudiantes universitarios. El sistema permite a los estudiantes conductores publicar recorridos indicando su origen, destino, horario y cantidad de cupos disponibles, mientras que los estudiantes pasajeros pueden buscar recorridos según sus necesidades y solicitar uno o varios cupos.

Entre las principales funcionalidades del sistema se encuentran la gestión de perfiles, publicación y administración de recorridos, búsqueda y gestión de solicitudes y cupos, ubicación de recogida o destino predeterminado, visualización mediante mapas, notificaciones, historial de recorridos y sistema de valoración.

El sistema también contempla un panel administrativo destinado a la gestión de usuarios, reportes, estadísticas e incidencias.

## Objetivos de calidad

| Prioridad | Objetivo de calidad | Descripción                                                                                                                      |
| --------- | ------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| 1         | **Rendimiento**     | Las búsquedas deben responder en menos de 2 segundos bajo condiciones normales.                                  |
| 2         | **Seguridad**       | Las contraseñas deben almacenarse mediante hashing con salt y las comunicaciones deben utilizar HTTPS.                           |
| 3         | **Disponibilidad**  | El sistema debe alcanzar una disponibilidad mínima del 99 % durante las franjas de mayor demanda.                                |
| 4         | **Escalabilidad**   | La arquitectura debe permitir el crecimiento del número de usuarios y recorridos sin degradar significativamente el rendimiento. |
| 5         | **Portabilidad**    | La aplicación debe funcionar de manera equivalente en Android e iOS.                                                             |
| 6         | **Mantenibilidad**  | El sistema debe utilizar una arquitectura modular y documentada que facilite su evolución.                                       |
| 7         | **Privacidad**      | Los datos personales deben tratarse de acuerdo con la Ley 1581 de 2012 y las políticas de protección de datos aplicables.        |
| 8         | **Usabilidad**      | Las acciones principales deben poder realizarse en un máximo de tres pasos.                                                      |

### Árbol de utilidad

El siguiente árbol de utilidad representa los principales atributos de calidad de ROUTB y sus respectivos subatributos:

```text
ROUTB
│
└── Calidad del sistema
    │
    ├── Rendimiento
    │   ├── Tiempo de respuesta
    │   └── Actualización de información en tiempo real
    │
    ├── Usabilidad
    │   ├── Facilidad de uso
    │   └── Navegación sencilla
    │
    ├── Seguridad
    │   ├── Autenticación
    │   └── Protección de datos
    │
    ├── Disponibilidad
    │   └── Acceso a funcionalidades principales
    │
    └── Escalabilidad
        └── Crecimiento
```

### Escenarios de calidad

| Atributo de calidad | Escenario | Medida |
|---|---|---|
| Rendimiento | Cuando un pasajero consulta los viajes disponibles, ROUTB procesa la solicitud y muestra los resultados. | El 95 % de las solicitudes debe responder en menos de 2 segundos bajo condiciones normales. |
| Usabilidad | Cuando un pasajero desea reservar un viaje disponible, el sistema permite realizar la reserva mediante un proceso sencillo y comprensible. | La reserva debe poder completarse en un máximo de 3 pasos principales. |
| Seguridad | Cuando un usuario no autorizado intenta acceder a un recurso protegido, ROUTB rechaza la solicitud. | El 100 % de los endpoints protegidos debe validar la autenticación y autorización. |
| Disponibilidad | Cuando un estudiante accede a la plataforma para consultar o reservar un viaje, las funcionalidades principales deben estar disponibles. | El sistema debe mantener una disponibilidad mínima del 99 % mensual. |
| Escalabilidad | Aumento progresivo de usuarios, viajes y reservas durante periodos de alta demanda. | Soportar 100 usuarios concurrentes sin errores ni interrupciones del servicio. |

## Stakeholders / Interesados

| Stakeholder                               | Interés / expectativa                                                                                           |
| ----------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| **Estudiante conductor**                  | Publicar recorridos, gestionar cupos y solicitudes y coordinar los puntos de recogida de los pasajeros.         |
| **Estudiante pasajero**                   | Encontrar recorridos compatibles, solicitar cupos, conocer el estado de sus solicitudes y gestionar sus viajes. |
| **Administrador**                         | Gestionar usuarios, reportes, estadísticas e incidencias y supervisar el funcionamiento de la plataforma.       |
| **Equipo de desarrollo**                  | Mantener una arquitectura modular, mantenible y documentada que permita evolucionar el sistema.                 |
| **Universidad / comunidad universitaria** | Contar con una plataforma orientada a facilitar la movilidad colaborativa entre estudiantes verificados.        |


# Restricciones de arquitectura
Restricciones técnicas

- Uso de Flutter para la aplicación móvil, ya que permite
  cubrir Android e iOS con una sola base de código y se
  ajusta al tiempo y recursos limitados del equipo.
- Uso de FastAPI/Python para el backend, por ser un framework
  ligero y rápido de implementar, acorde con la experiencia
  del equipo y el tiempo disponible en el semestre.
- Uso de una base de datos relacional, dado que la información
  del dominio (usuarios, recorridos, cupos, solicitudes) tiene
  relaciones claras entre sí que se ajustan bien a este modelo.
- Uso de JWT para la autenticación de sesiones, al ser un
  estándar para autenticación sin estado en APIs REST, lo que
  facilita la escalabilidad del backend.

Restricciones de integración

- Integración con un proveedor externo de mapas y
  geolocalización, ya que el equipo no cuenta con los recursos
  para desarrollar un motor de mapas propio.
- Integración con un servicio de notificaciones push, necesario
  para informar a los usuarios sobre cambios en sus recorridos
  o solicitudes sin depender de que tengan la app abierta.

Restricciones comerciales y de alcance

- ROUTB no gestiona pagos ni transacciones comerciales, dado que
  el transporte compartido se basa en acuerdos informales entre
  estudiantes y no en un servicio comercial regulado.
- ROUTB no actúa como operador de transporte, ya que los
  conductores son estudiantes que comparten su propio vehículo
  y no una flota contratada por la plataforma.
- La verificación de antecedentes o idoneidad de los conductores
  está fuera del alcance del sistema, porque implicaría acceso a
  bases de datos oficiales y procesos legales que exceden las
  posibilidades de un proyecto académico.
- El desarrollo debe ajustarse al cronograma académico del
  semestre, con entregas incrementales por semana, lo cual
  limita el alcance funcional que el equipo puede completar en
  el tiempo disponible.

# Contexto y alcance

ROUTB es una plataforma de movilidad colaborativa dirigida a estudiantes universitarios. El sistema permite a estudiantes conductores publicar recorridos y gestionar los cupos disponibles, mientras que los estudiantes pasajeros pueden consultar recorridos, solicitar uno o varios cupos y gestionar sus viajes. Los administradores utilizan la plataforma para supervisar usuarios, reportes, estadísticas e incidencias.

## Contexto empresarial

Representa la relación entre la plataforma y los principales actores involucrados en la movilidad colaborativa universitaria.

```mermaid
flowchart LR

    C["Estudiante<br/>Conductor"]
    P["Estudiante<br/>Pasajero"]
    U["Universidad /<br/>Comunidad universitaria"]
    A["Administrador"]

    R["ROUTB<br/><br/>Plataforma de movilidad<br/>colaborativa"]

    C -->|"Publica recorridos<br/>y ofrece cupos"| R
    P -->|"Busca recorridos<br/>y solicita cupos"| R
    A -->|"Gestiona usuarios,<br/>reportes e incidencias"| R
    U -.->|"Entorno institucional"| R

    R -->|"Facilita la coordinación<br/>de viajes"| C
    R -->|"Facilita el acceso<br/>a transporte"| P

    classDef actor fill:#111827,stroke:#a855f7,color:#ffffff,stroke-width:2px
    classDef system fill:#064e3b,stroke:#2dd4bf,color:#ffffff,stroke-width:3px
    classDef institution fill:#111827,stroke:#60a5fa,color:#ffffff,stroke-width:2px

    class C,P,A actor
    class R system
    class U institution

    linkStyle default stroke:#d1d5db,stroke-width:2px,color:#ffffff
```
| Interfaz                                  | Relación con ROUTB                                                            |
| ----------------------------------------- | ----------------------------------------------------------------------------- |
| **Estudiante conductor**                  | Ofrece recorridos, administra cupos y gestiona solicitudes.                   |
| **Estudiante pasajero**                   | Consulta recorridos, solicita cupos y gestiona sus viajes.                    |
| **Administrador**                         | Supervisa usuarios, reportes, estadísticas e incidencias.                     |
| **Universidad / comunidad universitaria** | Representa el entorno institucional y la población objetivo de la plataforma. |


## Contexto tecnico

Representa los principales sistemas y canales mediante los cuales ROUTB recibe, procesa, almacena e intercambia información.

```mermaid
flowchart LR

    U["Usuario"]

    APP["Aplicación móvil<br/>Flutter"]

    R["ROUTB<br/>Backend FastAPI"]

    DB[("PostgreSQL")]

    MAP["Servicio externo<br/>Mapas y geolocalización"]

    PUSH["Servicio externo<br/>Notificaciones Push"]


    U -->|"Interacción"| APP
    APP -->|"HTTPS / REST"| R

    R -->|"SQL"| DB

    R -->|"HTTPS / API"| MAP
    R -->|"HTTPS / API"| PUSH

    PUSH -->|"Push"| APP


    classDef user fill:#111827,stroke:#a855f7,color:#fff,stroke-width:2px
    classDef app fill:#111827,stroke:#a855f7,color:#fff,stroke-width:2px
    classDef system fill:#111827,stroke:#2dd4bf,color:#fff,stroke-width:2px
    classDef database fill:#111827,stroke:#60a5fa,color:#fff,stroke-width:2px
    classDef external fill:#111827,stroke:#f59e0b,color:#fff,stroke-width:2px

    class U user
    class APP app
    class R system
    class DB database
    class MAP,PUSH external
```

| Interfaz                          | Canal            | Propósito                                                                        |
| --------------------------------- | ---------------- | -------------------------------------------------------------------------------- |
| **Usuario ↔ Aplicación móvil**    | Interfaz gráfica | Registro, autenticación, consulta y gestión de recorridos, solicitudes y viajes. |
| **Flutter ↔ FastAPI**             | HTTPS / REST     | Intercambio de información entre la aplicación móvil y el backend.               |
| **FastAPI ↔ PostgreSQL**          | SQL              | Persistencia y consulta de usuarios, recorridos, solicitudes, cupos e historial. |
| **FastAPI ↔ Servicio de mapas**   | HTTPS / API      | Consulta de mapas, ubicaciones y geolocalización.                                |
| **FastAPI ↔ Notificaciones Push** | HTTPS / API      | Envío de notificaciones relacionadas con recorridos y solicitudes.               |
| **Notificaciones Push → Flutter** | Push             | Entrega de notificaciones al dispositivo del usuario.                            |


| Entrada / Salida                 | Origen / Destino          | Canal                       |
| -------------------------------- | ------------------------- | --------------------------- |
| Credenciales y datos de registro | Usuario → ROUTB           | HTTPS / REST                |
| Solicitudes de recorridos        | Usuario → ROUTB           | HTTPS / REST                |
| Información de recorridos        | ROUTB → Usuario           | HTTPS / REST                |
| Gestión de cupos y solicitudes   | Usuario ↔ ROUTB           | HTTPS / REST                |
| Ubicaciones                      | Usuario ↔ ROUTB           | HTTPS / REST + API de mapas |
| Datos de mapas                   | Servicio de mapas → ROUTB | HTTPS / API                 |
| Datos persistentes               | ROUTB ↔ PostgreSQL        | SQL                         |
| Notificaciones                   | ROUTB → Usuario           | Servicio Push               |



# Solution Strategy

## Decisiones tecnológicas

| Tecnología | Rol en la arquitectura | Justificación |
| --- | --- | --- |
| **Flutter** | Framework para el cliente móvil (Android/iOS) | Permite un único código base multiplataforma, cumpliendo el requisito de portabilidad (RNF-006) con menor esfuerzo de desarrollo para un equipo reducido de 4 integrantes. |
| **FastAPI (Python)** | Framework del backend / API REST | Alto rendimiento para operaciones asíncronas (relevante para el matching y las búsquedas, RNF-001), tipado y validación de datos integrados, y curva de aprendizaje adecuada para un proyecto académico. |
| **PostgreSQL** | Modelo relacional adecuado para las entidades del dominio (usuarios, recorridos, cupos, solicitudes) y sus relaciones; soporta las consultas de localización necesarias para la búsqueda de recorridos. |
| **JWT** | Autenticación y gestión de sesiones | Mecanismo *stateless* que simplifica la escalabilidad horizontal del backend (RNF-005) y se integra naturalmente con FastAPI. |
| **HTTPS** | Protección de las comunicaciones cliente-servidor | Requisito directo de seguridad (RNF-002). |
| **API de mapas y geolocalización** (Google Maps API / OpenStreetMap) | Visualización de rutas y cálculo de coincidencias | Se trata como una dependencia externa integrada mediante una interfaz propia, evitando acoplar el dominio de negocio al proveedor específico. |
| **Servicio de notificaciones push** (p. ej. Firebase Cloud Messaging) | Notificaciones a usuarios | Integración externa desacoplada mediante un adaptador, permitiendo sustituir el proveedor sin afectar el core del sistema. |

## Decisiones de descomposición y organización del sistema

La solución se organiza en torno a cuatro grandes bloques, que se detallarán en la vista de bloques de construcción (sección 5):

- **Aplicación móvil (Flutter):** capa de presentación e interacción con el usuario (conductor, pasajero, administrador).
- **Backend / API (FastAPI):** contiene la lógica de negocio — autenticación, gestión de recorridos y cupos, reputación y estadísticas — expuesta como API REST.
- **Persistencia de datos (PostgreSQL):** almacenamiento de usuarios, recorridos, solicitudes, historial y reputación.
- **Integraciones externas:** servicio de mapas/geolocalización y servicio de notificaciones push. Estas se tratan como dependencias externas, aisladas del dominio mediante interfaces de integración, de modo que puedan reemplazarse sin impactar la lógica central del negocio.

Esta separación busca mantener el sistema modular y comprensible para los cuatro integrantes del equipo, permitiendo que distintos miembros trabajen en paralelo sobre el cliente, el backend y las integraciones sin generar dependencias cruzadas fuertes

## Enfoque para alcanzar los objetivos de calidad clave

| Objetivo de calidad (prioridad) | Estrategia arquitectónica |
| --- | --- |
| Rendimiento (1) | Búsquedas optimizadas con consultas geoespaciales indexadas en PostgreSQL/PostGIS; operaciones críticas de búsqueda diseñadas para responder en menos de 2 segundos (RNF-001). |
| Seguridad (2) | Hashing de contraseñas con salt, autenticación basada en JWT, y HTTPS obligatorio en toda comunicación cliente-servidor (RNF-002). |
| Disponibilidad (3) | Backend sin estado (stateless, gracias a JWT) que facilita el despliegue de múltiples instancias durante las franjas de mayor demanda. |
| Escalabilidad (4) | Arquitectura desacoplada en capas (cliente / API / persistencia / integraciones externas) que permite escalar el backend horizontalmente a medida que crece la cantidad de usuarios y recorridos por semestre. |
| Portabilidad (5) | Un único código base en Flutter para Android e iOS. |
| Mantenibilidad (6) | Backend organizado en módulos por dominio (autenticación, recorridos, búsqueda, reputación, administración), documentado y con responsabilidades claras entre los miembros del equipo. |
| Privacidad (7) | tratamiento de datos personales conforme a la Ley 1581 de 2012. |
| Usabilidad (8) | Diseño mobile-first con flujos de máximo 3 pasos para las acciones principales (publicar, buscar, solicitar un cupo). |

## Decisiones organizacionales

- El desarrollo se distribuye entre los cuatro integrantes del equipo según los bloques definidos (cliente móvil, backend/API, persistencia, integraciones), minimizando el trabajo simultáneo sobre un mismo componente.
- Al ser un proyecto académico de un semestre, se prioriza una arquitectura simple y bien documentada por sobre patrones más complejos (p. ej. microservicios), reservando la posibilidad de evolucionar hacia una arquitectura más distribuida si el sistema creciera más allá del alcance actual.
- Las integraciones externas (mapas, notificaciones) se aíslan explícitamente del dominio de negocio para poder desarrollarlas, probarlas y sustituirlas de forma independiente.


# Building Block View

## Whitebox Overall System

***\<Overview Diagram\>***

Motivation

:   *\<text explanation\>*

Contained Building Blocks

:   *\<Description of contained building block (black boxes)\>*

Important Interfaces

:   *\<Description of important interfaces\>*

### \<Name black box 1\> {#_name_black_box_1}

*\<Purpose/Responsibility\>*

*\<Interface(s)\>*

*\<(Optional) Quality/Performance Characteristics\>*

*\<(Optional) Directory/File Location\>*

*\<(Optional) Fulfilled Requirements\>*

*\<(optional) Open Issues/Problems/Risks\>*

### \<Name black box 2\> {#_name_black_box_2}

*\<black box template\>*

### \<Name black box n\> {#_name_black_box_n}

*\<black box template\>*

### \<Name interface 1\> {#_name_interface_1}

...​

### \<Name interface m\> {#_name_interface_m}

## Level 2 {#_level_2}

### White Box *\<building block 1\>* {#_white_box_building_block_1}

*\<white box template\>*

### White Box *\<building block 2\>* {#_white_box_building_block_2}

*\<white box template\>*

...​

### White Box *\<building block m\>* {#_white_box_building_block_m}

*\<white box template\>*

## Level 3 {#_level_3}

### White Box \<\_building block x.1\_\> {#_white_box_building_block_x_1}

*\<white box template\>*

### White Box \<\_building block x.2\_\> {#_white_box_building_block_x_2}

*\<white box template\>*

### White Box \<\_building block y.1\_\> {#_white_box_building_block_y_1}

*\<white box template\>*

# Runtime View {#section-runtime-view}

## \<Runtime Scenario 1\> {#_runtime_scenario_1}

-   *\<insert runtime diagram or textual description of the scenario\>*

-   *\<insert description of the notable aspects of the interactions
    between the building block instances depicted in this diagram.\>*

## \<Runtime Scenario 2\> {#_runtime_scenario_2}

## ...​

## \<Runtime Scenario n\> {#_runtime_scenario_n}

# Deployment View {#section-deployment-view}

## Infrastructure Level 1 {#_infrastructure_level_1}

***\<Overview Diagram\>***

Motivation

:   *\<explanation in text form\>*

Quality and/or Performance Features

:   *\<explanation in text form\>*

Mapping of Building Blocks to Infrastructure

:   *\<description of the mapping\>*

## Infrastructure Level 2 {#_infrastructure_level_2}

### *\<Infrastructure Element 1\>* {#_infrastructure_element_1}

*\<diagram + explanation\>*

### *\<Infrastructure Element 2\>* {#_infrastructure_element_2}

*\<diagram + explanation\>*

...​

### *\<Infrastructure Element n\>* {#_infrastructure_element_n}

*\<diagram + explanation\>*

# Cross-cutting Concepts {#section-concepts}

## *\<Concept 1\>* {#_concept_1}

*\<explanation\>*

## *\<Concept 2\>* {#_concept_2}

*\<explanation\>*

...​

## *\<Concept n\>* {#_concept_n}

*\<explanation\>*

# Architecture Decisions {#section-design-decisions}

# Quality Requirements {#section-quality-scenarios}

## Quality Requirements Overview {#_quality_requirements_overview}

## Quality Scenarios {#_quality_scenarios}

# Risks and Technical Debts {#section-technical-risks}

# Glossary {#section-glossary}

+----------------------+-----------------------------------------------+
| Term                 | Definition                                    |
+======================+===============================================+
| *\<Term-1\>*         | *\<definition-1\>*                            |
+----------------------+-----------------------------------------------+
| *\<Term-2\>*         | *\<definition-2\>*                            |
+----------------------+-----------------------------------------------+
