# 7. Vista de despliegue
 
Esta vista muestra dónde funciona cada parte de ROUTB: en el celular del usuario, en el servidor que ejecuta la aplicación y en el servicio que guarda los datos. También explica por qué se eligió cada plataforma, con enlaces a las decisiones de arquitectura (ADR). Todo el sistema funciona sin costo mensual ($0.00 USD) y sin tarjetas bancarias.
 
---
 
## 7.1 Infraestructura - Nivel 1
 
El siguiente diagrama presenta cada pieza del sistema, dónde se ejecuta y cómo se comunica con las demás:
 
```mermaid
flowchart LR
    U["Usuario<br/>(Estudiante / Conductor)"]
 
    subgraph CLIENT["Celular del usuario"]
        APP["App ROUTB<br/><b>Dónde funciona:</b> en el celular (Android o iOS)"]
    end
 
    subgraph CLOUD_DOKPLOY["Dokploy"]
        API["Servidor de ROUTB<br/><b>Dónde funciona:</b> contenedor Docker en servidor propio"]
    end
 
    subgraph CLOUD_SUPABASE["Supabase"]
        DB[("Base de datos<br/><b>Dónde funciona:</b> proyecto en Supabase")]
    end
 
    subgraph EXTERNAL["Servicios externos"]
        MAP["Mapas y ubicación<br/><b>Dónde funciona:</b> proveedor de mapas"]
        PUSH["Notificaciones<br/><b>Dónde funciona:</b> Firebase Cloud Messaging"]
    end
 
    U -->|"Usa la pantalla del celular"| APP
    APP -->|"Envía y recibe datos<br/>(conexión segura HTTPS)"| API
    APP -->|"Pide mapas<br/>(conexión segura HTTPS)"| MAP
    API -->|"Guarda y consulta datos<br/>(conexión cifrada)"| DB
    API -->|"Envía avisos<br/>(conexión segura HTTPS)"| PUSH
```
 
### Por qué está organizado así
 
ROUTB funciona como un sistema con tres partes que se reparten el trabajo: la app del celular, el servidor y la base de datos.
 
1. **Cada parte hace lo suyo.** El servidor concentra las reglas del negocio y el control de cupos. Los datos se guardan aparte, en un servicio administrado en internet.
2. **Infraestructura del proyecto.** El servidor corre en una máquina propia administrada con Dokploy y la base de datos se guarda en el plan gratuito de Supabase (ver [ADR 0015](../adr/0015-dokploy-plataforma-de-despliegue.md) y [ADR 0006](../adr/0006-base-de-datos-supabase.md)).
3. **Comunicación protegida.** Todo lo que viaja por internet va cifrado.
### Qué pieza corre dónde
 
| Pieza | Dónde funciona | Plataforma | Cómo se comunica | Decisión asociada |
|---|---|---|---|---|
| **App ROUTB** | En el celular del estudiante | App Flutter (Android / iOS) | Conexión segura con el servidor y con los mapas | [ADR 0004 - Integración síncrona REST](../adr/0004-integracion-sincrona-rest.md) |
| **Servidor de ROUTB** | Contenedor Docker en un servidor propio | **Dokploy** | Recibe las peticiones de la app por una dirección web segura | [ADR 0015 - Despliegue en Dokploy](../adr/0015-dokploy-plataforma-de-despliegue.md) |
| **Base de datos** | Servicio de base de datos administrado | **Supabase** | Conexión cifrada con el servidor | [ADR 0006 - Base de datos en Supabase](../adr/0006-base-de-datos-supabase.md) |
| **Mapas y ubicación** | Servidores del proveedor de mapas | Proveedor externo (OpenStreetMap / Google) | Conexión segura desde la app | Servicio externo |
| **Notificaciones** | Plataforma de mensajería de Google | Firebase Cloud Messaging | Conexión segura desde el servidor | Servicio externo |
 
---
 
## 7.2 Infraestructura - Nivel 2
 
El siguiente diagrama muestra con más detalle qué hay dentro de cada plataforma:
 
```mermaid
flowchart TD
    subgraph USER_ENV["Celular del usuario"]
        CLIENT_APP["App ROUTB (Flutter)"]
    end
 
    subgraph DOKPLOY_NODE["Dokploy (servidor propio)"]
        subgraph SERVER["Servidor de ROUTB"]
            REGISTRO["Registro de actividad<br/>(anota cada petición y cuánto tardó)"]
            MODULES["Módulos<br/>autenticación · usuarios · viajes · solicitudes"]
            REGISTRO --> MODULES
        end
        CONFIG["Claves y datos de conexión<br/>(guardados en el panel de Dokploy)"]
        CONFIG -.->|"Se entregan al iniciar"| SERVER
    end
 
    subgraph SUPABASE_NODE["Supabase (plan gratuito)"]
        DB_CORE[("Base de datos<br/>Usuarios, viajes y solicitudes de reserva")]
    end
 
    CLIENT_APP -->|"Conexión segura HTTPS"| REGISTRO
    MODULES -->|"Conexión cifrada"| DB_CORE
```
 
### 7.2.1 App ROUTB (celular)
- **Dónde funciona:** en el celular (Android o iOS) del estudiante o conductor.
- **Qué hace:** muestra las pantallas (inicio de sesión, búsqueda de viajes, solicitud de cupos), toma la ubicación del dispositivo y pide la información al servidor.
- **Con quién habla:** con el servidor, en `https://routb.iscoutb.dev`.
- **Decisión asociada:** [ADR 0004 - Integración síncrona REST](../adr/0004-integracion-sincrona-rest.md).
### 7.2.2 Servidor de ROUTB (Dokploy)
- **Dónde funciona:** en un servidor propio, administrado con **Dokploy**. La aplicación va empacada en un contenedor (Docker) construido a partir de `backend/Dockerfile`.
- **Seguridad:** el servidor se ejecuta con permisos limitados, solo los necesarios para funcionar.
- **Claves y contraseñas:** se guardan en el panel de Dokploy y nunca en el repositorio (ver [Sección 8.3](08_conceptos_transversales.md#83-gestión-de-secretos-y-configuración)).
- **Registro de actividad:** anota cada petición recibida y cuánto tardó en responder. Dokploy conserva esos registros (ver [Sección 8.4](08_conceptos_transversales.md#84-observabilidad-y-logging-estructurado)).
- **Decisión asociada:** [ADR 0015 - Plataforma de despliegue del backend (Dokploy)](../adr/0015-dokploy-plataforma-de-despliegue.md).
### 7.2.3 Base de datos (Supabase)
- **Dónde funciona:** como un proyecto de base de datos administrado en **Supabase**, en su plan gratuito.
- **Qué guarda:** de forma permanente los usuarios, los viajes y las solicitudes de reserva.
- **Cómo se conecta:** el servidor se comunica con ella por una conexión cifrada, y un intermediario de la plataforma reutiliza las conexiones para no saturarla.
- **Cambios en la estructura:** se hacen mediante migraciones versionadas en el repositorio, de modo que cada cambio queda registrado.
- **Decisión asociada:** [ADR 0006 - Elección de plataforma para la base de datos (Supabase)](../adr/0006-base-de-datos-supabase.md).
### 7.2.4 Servicios externos (mapas y notificaciones)
- **Mapas y ubicación:** los usa la app directamente, por conexión segura, para mostrar mapas y rutas.
- **Notificaciones:** las envía el servidor para avisar a pasajeros y conductores sobre el estado de sus reservas.
---
 
## 7.3 Limitaciones de los planes gratuitos
 
Las piezas que siguen en un plan gratuito del proveedor son la base de datos y el pipeline de CI/CD:
 
| Pieza | Qué pasa | Qué efecto tiene | Dónde está documentado |
|---|---|---|---|
| **Base de datos (Supabase)** | Se pausa si pasan 7 días sin uso | Se reactiva desde el panel de Supabase, sin perder datos ni cambiar su estructura | [ADR 0006](../adr/0006-base-de-datos-supabase.md) |

El servidor del backend ya no sufre esta limitación: al correr en un servidor propio,
no se suspende por inactividad y no presenta arranques en frío
(ver [ADR 0015](../adr/0015-dokploy-plataforma-de-despliegue.md)).
 
### Cómo se verifica
 
- **Que el servicio está activo:** [Verificación de despliegue en Dokploy](../evidencia/despliegue-dokploy.md).
- **Que responde con rapidez:** hay dos registros. El procedimiento completo (N=100) está en [Métrica de calidad consultable](../evidencia/metricas-escenario-calidad.md), ejecutado sobre Render, y la comprobación externa sobre Dokploy en [Verificación de despliegue en Dokploy](../evidencia/despliegue-dokploy.md). Ninguno de los dos mide el arranque en frío, porque ese tiempo ocurre antes de que el registro de actividad empiece a contar.
- **Que no genera costo:** [Costo mensual](../evidencia/costo_mensual.md).
