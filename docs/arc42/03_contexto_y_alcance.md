# 3. Contexto y alcance

ROUTB es una plataforma de movilidad colaborativa dirigida a estudiantes universitarios. El sistema permite a estudiantes conductores publicar recorridos y gestionar los cupos disponibles, mientras que los estudiantes pasajeros pueden consultar recorridos, solicitar uno o varios cupos y gestionar sus viajes. Los administradores utilizan la plataforma para supervisar usuarios, reportes, estadísticas e incidencias.

## 3.1 Contexto empresarial

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
    class C,P,A actor
    class R system

    linkStyle default stroke:#d1d5db,stroke-width:2px,color:#ffffff
```
| Interfaz                                  | Relación con ROUTB                                                            |
| ----------------------------------------- | ----------------------------------------------------------------------------- |
| **Estudiante conductor**                  | Ofrece recorridos, administra cupos y gestiona solicitudes.                   |
| **Estudiante pasajero**                   | Consulta recorridos, solicita cupos y gestiona sus viajes.                    |
| **Administrador**                         | Supervisa usuarios, reportes, estadísticas e incidencias.                     |


## 3.2 Contexto tecnico

Representa los principales sistemas y canales mediante los cuales ROUTB recibe, procesa, almacena e intercambia información.

```mermaid
flowchart LR

    U["Usuario"]

    R["ROUTB<br/>Plataforma de movilidad<br/>colaborativa"]

    MAP["Servicio externo<br/>Mapas y geolocalización"]

    PUSH["Servicio externo<br/>Notificaciones Push"]


    U -->|"Interacción"| R

    R -->|"HTTPS / API"| MAP
    R -->|"HTTPS / API"| PUSH


    classDef user fill:#111827,stroke:#a855f7,color:#fff,stroke-width:2px
    classDef system fill:#111827,stroke:#2dd4bf,color:#fff,stroke-width:2px
    classDef external fill:#111827,stroke:#f59e0b,color:#fff,stroke-width:2px

    class U user
    class R system
    class MAP,PUSH external
```

| Interfaz                          | Canal            | Propósito                                                                        |
| --------------------------------- | ---------------- | -------------------------------------------------------------------------------- |
| **Usuario ↔ ROUTB**               | Interfaz cliente | Registro, autenticación, consulta y gestión de recorridos, solicitudes y viajes. |
| **ROUTB ↔ Servicio de mapas**     | HTTPS / API      | Consulta de mapas, ubicaciones y geolocalización.                                |
| **ROUTB ↔ Notificaciones Push**   | HTTPS / API      | Envío de notificaciones relacionadas con recorridos y solicitudes.               |


| Entrada / Salida                 | Origen / Destino          | Canal                       |
| -------------------------------- | ------------------------- | --------------------------- |
| Credenciales y datos de registro | Usuario → ROUTB           | HTTPS / REST                |
| Solicitudes de recorridos        | Usuario → ROUTB           | HTTPS / REST                |
| Información de recorridos        | ROUTB → Usuario           | HTTPS / REST                |
| Gestión de cupos y solicitudes   | Usuario ↔ ROUTB           | HTTPS / REST                |
| Ubicaciones                      | Usuario ↔ ROUTB           | HTTPS / REST + API de mapas |
| Datos de mapas                   | Servicio de mapas → ROUTB | HTTPS / API                 |
| Datos persistentes               | ROUTB ↔ Persistencia        | SQL                         |
| Notificaciones                   | ROUTB → Usuario           | Servicio Push               |
