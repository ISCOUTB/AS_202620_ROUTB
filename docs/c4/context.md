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
