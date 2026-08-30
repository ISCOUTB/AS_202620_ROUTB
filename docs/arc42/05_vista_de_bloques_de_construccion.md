# 5. Vista de bloques de construcción

## 5.1 Nivel 1: Whitebox del sistema completo

**Diagrama general:**

[Diagrama C4](../c4/context.md)

**Motivación:**
ROUTB se organiza en cuatro bloques principales para separar claramente la interacción con el usuario, la lógica de negocio, la persistencia de datos y las dependencias con servicios de terceros. Esta separación facilita el trabajo paralelo del equipo, el aislamiento de fallos y el mantenimiento a largo plazo del sistema.

**Bloques de Construcción:**

| Nombre | Descripción |
| :--- | :--- |
| **Aplicación Móvil** | Interfaz de usuario para conductores, pasajeros y administradores. Permite registrarse, publicar y buscar recorridos, solicitar cupos, calificar viajes y recibir notificaciones. Construida con Flutter para Android e iOS. |
| **Backend / API (Monolito Modular)** | Contiene la lógica de negocio central del sistema. Implementado en Python usando FastAPI y Uvicorn. Se encarga de la autenticación, gestión de recorridos, emparejamiento geoespacial y administración general. |
| **Base de Datos** | Almacena de forma persistente la información de usuarios, recorridos, solicitudes, historial de viajes y reputación. Utiliza PostgreSQL con la extensión PostGIS para las consultas geoespaciales. |
| **Integraciones Externas** | Conjunto de servicios de terceros consumidos por el backend. Incluye el servicio de mapas/geolocalización y el servicio de envío de notificaciones push. |

**Interfaces Importantes:**
*   API REST sobre HTTPS entre la aplicación móvil y el Backend.
*   Protocolo SQL TCP/IP entre el Backend y la Base de Datos.
*   APIs REST/SDK de terceros entre el Backend y las Integraciones Externas (mapas, notificaciones push).

---

## 5.2 Nivel 2: Whitebox del Backend

**Diagrama de Nivel 2:**

[Diagrama C4](../c4/context.md)

**Motivación:**
Se adoptó un modelo de **Monolito Modular** como estrategia arquitectónica [ADR 0001](../adr/0001-usar-monolito-modular.md).

**Bloques de Construcción (Módulos Internos):**

| Módulo | Propósito y Responsabilidades |
| :--- | :--- |
| **`auth`** | Gestión de autenticación, registro, inicio de sesión y emisión/validación de tokens de seguridad (JWT). |
| **`users`** | Administración de perfiles de usuario, preferencias y cálculo del puntaje de reputación mediante calificaciones históricas. |
| **`trips`** | Gestión de los recorridos: publicación, edición, cancelación y búsqueda de recorridos compatibles usando rutas y horarios. |
| **`requests`** | Control del ciclo de vida de la solicitud de cupos (creación, aceptación, rechazo o cancelación) entre pasajero y conductor. |
| **`notifications`** | Adaptadores y lógica para la generación de alertas del sistema y consumo del proveedor externo de notificaciones push. |
| **`admin`** | Funciones administrativas para moderación de usuarios, resolución de incidencias y estadísticas. |
| **`shared`** | Código transversal o común utilizado por múltiples módulos (ej. manejo de errores global, utilidades compartidas, conexión a BD), asegurando que los módulos de negocio no se acoplen entre sí. |

Cada módulo expone sus funciones internamente y comparte el acceso a la base de datos a través de una capa de persistencia común, evitando que distintos módulos implementen accesos redundantes o inconsistentes a las mismas tablas.

---
