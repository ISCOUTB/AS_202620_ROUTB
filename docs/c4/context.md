```mermaid
flowchart TD

    EC["Estudiante Conductor<br/><br/>• Publica recorridos<br/>• Gestiona cupos<br/>• Gestiona solicitudes"]

    EP["Estudiante Pasajero<br/><br/>• Busca recorridos<br/>• Solicita cupos<br/>• Gestiona viajes"]

    R["ROUTB<br/><br/>Plataforma de Movilidad<br/>Colaborativa para<br/>Estudiantes"]

    MAP["Servicio de<br/>Mapas y<br/>Geolocalización<br/><br/>• Mapas<br/>• Ubicaciones"]

    PUSH["Servicio de<br/>Notificaciones Push<br/><br/>• Avisos de eventos<br/>• Notificaciones<br/>del sistema"]

    ADM["Administrador<br/><br/>• Gestiona usuarios<br/>• Reportes<br/>• Estadísticas<br/>• Gestiona incidencias"]

    ROUTB(["ROUTB"])

    %% Conexiones principales
    EC --> R
    EP --> R

    R --> MAP
    R --> PUSH

    ADM --> ROUTB

    MAP ~~~ ADM
    PUSH ~~~ ADM

    %% Estilos
    classDef actor fill:#111827,stroke:#a855f7,color:#fff,stroke-width:2px
    classDef system fill:#111827,stroke:#a855f7,color:#fff,stroke-width:2px
    classDef service fill:#111827,stroke:#a855f7,color:#fff,stroke-width:2px
    classDef final fill:#064e3b,stroke:#2dd4bf,color:#fff,stroke-width:2px

    class EC,EP,ADM actor
    class R system
    class MAP,PUSH service
    class ROUTB final

    linkStyle 5,6 stroke-width:0px,opacity:0
