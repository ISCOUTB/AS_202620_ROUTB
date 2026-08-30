# 4. Estrategia de solución

## 4.1 Decisiones tecnológicas

| Tecnología | Rol en la arquitectura | Justificación |
| --- | --- | --- |
| **Flutter** | Framework para el cliente móvil (Android/iOS) | Permite un único código base multiplataforma, cumpliendo el requisito de portabilidad con menor esfuerzo de desarrollo para un equipo reducido de 4 integrantes. |
| **FastAPI (Python)** | Framework del backend / API REST | Alto rendimiento para operaciones asíncronas, tipado y validación de datos integrados, y curva de aprendizaje adecuada para un proyecto académico. |
| **PostgreSQL** | Base de datos relacional |Modelo relacional adecuado para las entidades del dominio (usuarios, recorridos, cupos, solicitudes) y sus relaciones; soporta las consultas de localización necesarias para la búsqueda de recorridos. |
| **JWT** | Autenticación y gestión de sesiones | Mecanismo *stateless* que simplifica la escalabilidad horizontal del backend y se integra naturalmente con FastAPI. |
| **HTTPS** | Protección de las comunicaciones cliente-servidor | Requisito directo de seguridad. |
| **API de mapas y geolocalización** (Google Maps API / OpenStreetMap) | Visualización de rutas y cálculo de coincidencias | Se trata como una dependencia externa integrada mediante una interfaz propia, evitando acoplar el dominio de negocio al proveedor específico. |
| **Servicio de notificaciones push** (p. ej. Firebase Cloud Messaging) | Notificaciones a usuarios | Integración externa desacoplada mediante un adaptador, permitiendo sustituir el proveedor sin afectar el core del sistema. |

## 4.2 Decisiones de descomposición y organización del sistema

La solución se organiza en torno a cuatro grandes bloques, que se detallarán en la vista de bloques de construcción (sección 5):

- **Aplicación móvil (Flutter):** capa de presentación e interacción con el usuario (conductor, pasajero, administrador).
- **Backend / API (FastAPI):** contiene la lógica de negocio — autenticación, gestión de recorridos y cupos, reputación y estadísticas — expuesta como API REST.
- **Persistencia de datos (PostgreSQL):** almacenamiento de usuarios, recorridos, solicitudes, historial y reputación.
- **Integraciones externas:** servicio de mapas/geolocalización y servicio de notificaciones push. Estas se tratan como dependencias externas, aisladas del dominio mediante interfaces de integración, de modo que puedan reemplazarse sin impactar la lógica central del negocio.

Esta separación busca mantener el sistema modular y comprensible para los cuatro integrantes del equipo, permitiendo que distintos miembros trabajen en paralelo sobre el cliente, el backend y las integraciones sin generar dependencias cruzadas fuertes

## 4.3 Enfoque para alcanzar los objetivos de calidad clave

| Objetivo de calidad (prioridad) | Estrategia arquitectónica |
| --- | --- |
| Rendimiento (1) | Búsquedas optimizadas con consultas geoespaciales indexadas en PostgreSQL/PostGIS; operaciones críticas de búsqueda diseñadas para responder en menos de 2 segundos. |
| Seguridad (2) | Hashing de contraseñas con salt, autenticación basada en JWT, y HTTPS obligatorio en toda comunicación cliente-servidor. |
| Disponibilidad (3) | Backend sin estado (stateless, gracias a JWT) que facilita el despliegue de múltiples instancias durante las franjas de mayor demanda. |
| Escalabilidad (4) | El monolito modular permite que, si un módulo concentra mayor carga (por ejemplo, búsqueda de recorridos), pueda optimizarse o incluso extraerse a futuro como servicio independiente sin rediseñar el resto del sistema. Ver [ADR 0001](../adr/0001-usar-monolito-modular.md). |
| Portabilidad (5) | Un único código base en Flutter para Android e iOS. |
| Mantenibilidad (6) | El backend se organiza como monolito modular, dividido en módulos independientes por dominio (autenticación, recorridos, búsqueda, reputación, administración), lo que permite a los desarrolladores del equipo trabajar en paralelo sobre distintos módulos, aislar pruebas y localizar cambios sin afectar el resto del sistema. Ver [ADR 0001](../adr/0001-usar-monolito-modular.md). |
| Privacidad (7) | Tratamiento de datos personales conforme a la Ley 1581 de 2012. |
| Usabilidad (8) | Diseño mobile-first con flujos de máximo 3 pasos para las acciones principales (publicar, buscar, solicitar un cupo). |

## 4.4 Decisiones organizacionales

- El desarrollo se distribuye entre los cuatro integrantes del equipo según los bloques definidos (cliente móvil, backend/API, persistencia, integraciones), minimizando el trabajo simultáneo sobre un mismo componente.
- Al ser un proyecto académico de un semestre, se prioriza una arquitectura simple y bien documentada por sobre patrones más complejos (p. ej. microservicios), reservando la posibilidad de evolucionar hacia una arquitectura más distribuida si el sistema creciera más allá del alcance actual.
- Las integraciones externas (mapas, notificaciones) se aíslan explícitamente del dominio de negocio para poder desarrollarlas, probarlas y sustituirlas de forma independiente.
