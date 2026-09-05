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
