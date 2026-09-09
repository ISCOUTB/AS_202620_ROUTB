**Nivel 1 — Contexto**

```mermaid
flowchart TD
    EC["Estudiante Conductor<br/>[Persona]<br/>"]
    EP["Estudiante Pasajero<br/>[Persona]<br/>"]
    ADM["Administrador<br/>[Persona]<br/>"]
    R["ROUTB<br/>[Sistema]<br/><br/>Plataforma de Movilidad<br/>Colaborativa para<br/>Estudiantes"]
    MAP["Servicio de<br/>Mapas y<br/>Geolocalización<br/>[Sistema Externo]<br/><br/>• Mapas<br/>• Ubicaciones"]
    PUSH["Servicio de<br/>Notificaciones Push<br/>[Sistema Externo]<br/><br/>• Avisos de eventos<br/>• Notificaciones<br/>del sistema"]
    %% Conexiones principales
    EC -->|"Publica recorridos, gestiona cupos y solicitudes"| R
    EP -->|"Busca recorridos, solicita cupos y gestiona viajes"| R
    ADM -->|"Gestiona usuarios, reportes e incidencias"| R
    R -->|"Consulta mapas y geolocalización"| MAP
    R -->|"Envía avisos y notificaciones"| PUSH
    %% Estilos
    classDef actor fill:#111827,stroke:#2dd4bf,color:#fff,stroke-width:2px
    classDef system fill:#064e3b,stroke:#2dd4bf,color:#fff,stroke-width:2px
    classDef service fill:#334155,stroke:#2dd4bf,color:#fff,stroke-width:2px
    class EC,EP,ADM actor
    class R system
    class MAP,PUSH service
```
| Elemento | Significado |
|---|---|
| Persona | Actor humano que interactúa con ROUTB |
| Sistema | ROUTB, el sistema en construcción por el equipo |
| Sistema Externo | Servicio de terceros, fuera del repositorio del equipo |

### Mapa de contextos funcionales

El sistema se organiza en contextos. Cada contexto tiene una responsabilidad principal y las relaciones representan
el tipo de colaboración entre ellos, no una separación física en servicios
independientes.

| Contexto | Responsabilidad | Relación principal |
|---|---|---|
| Identidad y Usuarios | Registrar usuarios, mantener perfiles, roles y autenticación. | Provee identidad y permisos a los demás contextos. |
| Gestión de Recorridos | Publicar recorridos y mantener la disponibilidad de cupos. | Expone recorridos y disponibilidad a Solicitudes y Reservas. |
| Solicitudes y Reservas | Gestionar solicitudes y confirmar reservas sin sobrepasar los cupos. | Consume recorridos y emite eventos de reserva. |
| Notificaciones | Informar solicitudes, reservas, cambios y disponibilidad. | Recibe eventos de Recorridos y Solicitudes y los entrega a los usuarios. |
| Administración | Supervisar usuarios, recorridos y solicitudes, además de gestionar reportes. | Consulta y gestiona los demás contextos según permisos administrativos. |


### Impacto de la restricción en el Nivel 1

En el nivel de contexto, la restricción de consistencia de cupos se refleja
como una responsabilidad de ROUTB frente a sus actores. El estudiante
conductor publica un recorrido con una cantidad limitada de cupos y el
estudiante pasajero puede solicitar una reserva, pero el sistema debe
garantizar que dos solicitudes simultáneas no generen una sobreventa. Este
nivel muestra la responsabilidad externa del sistema, mientras que el
mecanismo técnico que la cumple se detalla en el nivel de contenedores.

---

**Nivel 2 — Contenedores**

```mermaid
---
title: "[Contenedores] ROUTB - Nivel 2"
---
flowchart TD
    EC["Estudiante Conductor<br/>[Persona]"]
    EP["Estudiante Pasajero<br/>[Persona]"]
    ADM["Administrador<br/>[Persona]"]

    subgraph ROUTB["ROUTB · Plataforma de Movilidad Colaborativa"]
        APP["Aplicación Móvil<br/>[Contenedor: Flutter]<br/><br/>Interfaz para conductores,<br/>pasajeros y administrador"]
        API["API Backend<br/>[Contenedor: FastAPI · Monolito Modular]<br/><br/>Expone toda la funcionalidad<br/>de ROUTB vía API REST/JSON<br/><br/>(ADR 0001)"]
        DB[("Base de Datos<br/>[Contenedor: PostgreSQL]<br/><br/>Usuarios, recorridos, cupos,<br/>solicitudes, reputación e historial")]
    end

    MAP["Servicio de Mapas y<br/>Geolocalización<br/>[Sistema Externo]"]
    PUSH["Servicio de Notificaciones Push<br/>[Sistema Externo]"]

    EC -->|"Usa"| APP
    EP -->|"Usa"| APP
    ADM -->|"Usa"| APP
    APP -->|"Llamadas API<br/>[REST/JSON · HTTPS]"| API
    API -->|"Lee y escribe<br/>[SQL · asyncpg]"| DB
    API -->|"Consulta rutas y ubicaciones<br/>[REST/JSON · HTTPS]"| MAP
    API -->|"Solicita envío de notificaciones<br/>[REST/JSON · HTTPS]"| PUSH
    PUSH -.->|"Entrega notificaciones a<br/>[Push/FCM]"| EC
    PUSH -.->|"Entrega notificaciones a<br/>[Push/FCM]"| EP

    classDef actor fill:#111827,stroke:#2dd4bf,color:#fff,stroke-width:2px
    classDef container fill:#0e7490,stroke:#2dd4bf,color:#fff,stroke-width:2px
    classDef service fill:#334155,stroke:#2dd4bf,color:#fff,stroke-width:2px
    class EC,EP,ADM actor
    class APP,API,DB container
    class MAP,PUSH service
```

| Elemento | Significado |
|---|---|
| Persona | Actor humano |
| Contenedor | Pieza desplegable de ROUTB (app, API o BD) |
| Sistema Externo | Servicio de terceros, fuera del repositorio del equipo |

### Impacto de la restricción en el Nivel 2

La restricción se implementa principalmente entre los contenedores **API
Backend** y **Base de Datos**. La aplicación móvil solicita la reserva por
medio de la API; el backend ejecuta una actualización atómica condicionada a
que existan cupos disponibles y la base de datos persiste el resultado. De
esta forma, las solicitudes concurrentes compiten por la misma operación de
actualización y solo se aceptan reservas dentro del límite configurado.

Este nivel se relaciona directamente con el cambio implementado en el módulo
`trips`, sus endpoints de consulta y reserva, y la prueba de concurrencia que
valida 20 intentos sobre 4 cupos.

### Límites conservados tras el cambio

El cambio se mantuvo dentro del límite del contenedor **API Backend** y de la
persistencia de recorridos y cupos en la **Base de Datos**. No se modificaron
los actores del sistema, la aplicación móvil, ni las integraciones externas de
mapas y notificaciones. Tampoco se creó un servicio independiente: el
comportamiento se agregó al módulo `trips` dentro del monolito modular.

La prueba del cambio verifica precisamente este alcance: ejercita los
endpoints y la lógica de reservas del backend, comprueba la actualización de
la disponibilidad y no requiere modificar los límites de los contenedores
definidos en este nivel.

---

**Nivel 3 - Componentes**

```mermaid
---
title: "[Componentes] ROUTB - Nivel 3"
---

flowchart TD
    EC["Estudiante Conductor<br/>[Persona]"]
    EP["Estudiante Pasajero<br/>[Persona]"]
    ADM["Administrador<br/>[Persona]"]

    APP["Aplicación Móvil<br/>[Contenedor: Flutter]<br/><br/>Interfaz para conductores,<br/>pasajeros y administrador"]

    subgraph API["API Backend - FASTAPI<br/>"]

        REST["API REST / Presentación<br/>[Componente]<br/><br/>Expone endpoints, valida solicitudes<br/>y entrega respuestas JSON"]

        AUTH["Autenticación y Acceso<br/>[Componente]<br/><br/>Registro, inicio de sesión, JWT,<br/>sesión y autorización por rol"]

        USERS["Gestión de Usuarios<br/>[Componente]<br/><br/>Perfiles de estudiantes,<br/>conductores y pasajeros"]

        TRIPS["Gestión de Recorridos<br/>[Componente]<br/><br/>Crear, publicar, buscar, consultar,<br/>actualizar y cancelar recorridos"]

        REQUESTS["Solicitudes y Cupos<br/>[Componente]<br/><br/>Solicitar, aprobar o rechazar cupos;<br/>mantiene disponibilidad consistente"]

        NOTIFICATIONS["Notificaciones<br/>[Componente]<br/><br/>Genera avisos sobre solicitudes,<br/>cupos y cambios en recorridos"]

        REPUTATION["Reputación e Historial<br/>[Componente]<br/><br/>Calificaciones, comentarios<br/>e historial de viajes"]

        ADMIN["Administración<br/>[Componente]<br/><br/>Gestión, moderación y estadísticas<br/>de la plataforma"]

        MAP_ADAPTER["Adaptador de Mapas<br/>[Componente]<br/><br/>Consulta rutas, ubicación,<br/>distancia y duración"]

        PUSH_ADAPTER["Adaptador de Push<br/>[Componente]<br/><br/>Solicita el envío de<br/>notificaciones a dispositivos"]

        PERSISTENCE["Persistencia Compartida<br/>[Componente: SQLAlchemy ORM]<br/><br/>Sesiones, entidades ORM,<br/>consultas y transacciones"]
    end

    DB[("Base de Datos<br/>[Contenedor: PostgreSQL]")]

    MAP["Servicio de Mapas y<br/>Geolocalización<br/>[Sistema Externo]"]

    PUSH["Servicio de<br/>Notificaciones Push<br/>[Sistema Externo]"]

    EC -->|"Usa"| APP
    EP -->|"Usa"| APP
    ADM -->|"Usa"| APP

    APP -->|"REST/JSON · HTTPS"| REST

    REST --> AUTH
    REST --> USERS
    REST --> TRIPS
    REST --> REQUESTS
    REST --> REPUTATION
    REST --> ADMIN

    USERS --> PERSISTENCE
    TRIPS --> PERSISTENCE
    REQUESTS --> PERSISTENCE
    REPUTATION --> PERSISTENCE
    ADMIN --> PERSISTENCE
    AUTH --> PERSISTENCE

    TRIPS --> MAP_ADAPTER
    MAP_ADAPTER -->|"REST/JSON · HTTPS"| MAP

    REQUESTS --> NOTIFICATIONS
    TRIPS --> NOTIFICATIONS
    NOTIFICATIONS --> PUSH_ADAPTER
    PUSH_ADAPTER -->|"REST/JSON · HTTPS"| PUSH

    PERSISTENCE -->|"SQL"| DB

    PUSH -.->|"Push / FCM"| EC
    PUSH -.->|"Push / FCM"| EP

    classDef actor fill:#111827,stroke:#2dd4bf,color:#fff,stroke-width:2px
    classDef container fill:#0e7490,stroke:#2dd4bf,color:#fff,stroke-width:2px
    classDef component fill:#155e75,stroke:#67e8f9,color:#fff,stroke-width:2px
    classDef service fill:#334155,stroke:#2dd4bf,color:#fff,stroke-width:2px

    class EC,EP,ADM actor
    class APP,DB container
    class REST,AUTH,USERS,TRIPS,REQUESTS,NOTIFICATIONS,REPUTATION,ADMIN,MAP_ADAPTER,PUSH_ADAPTER,PERSISTENCE component
    class MAP,PUSH service
```
| Elemento | Significado |
|---|---|
| Persona | Actor humano |
| Contenedor | Pieza desplegable de ROUTB (app, API o BD) |
| Componente | Módulo con código real dentro del backend (router · service · models · schemas, según ADR 0002) |
| Sistema Externo | Servicio de terceros, fuera del repositorio del equipo |
