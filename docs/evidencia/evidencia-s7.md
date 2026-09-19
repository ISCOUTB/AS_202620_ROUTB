# Evidencia S7 · Contrato de API y prueba de contrato
**Asignatura:** Arquitecturas de Software (2026-2)  
**Equipo:** ROUTB (`ISCOUTB/AS_202620_ROUTB`)  
**Integrantes:** Diego José Barón Ruiz · Julián David Manjarrez Guzmán · Keiner Enrique Mendivil Díaz · Junior José Orozco Atencio  
**Rama:** `Changes` / `master`  
**Identificador Moodle:** `arqsw:evidencia-s7`  

---

## 1. Resumen Ejecutivo de la Entrega

Durante la Semana 7 se formalizó y blindó la superficie de comunicación de **ROUTB** mediante la especificación ejecutable de su contrato de API, la incorporación de pruebas automatizadas de contrato en el pipeline de Integración Continua (CI) y la justificación arquitectónica de la estrategia de integración externa.

| Componente | Artefacto en el Repositorio | Descripción / Función |
|---|---|---|
| **Contrato de API Versionado** | [`docs/openapi.json`](../openapi.json) | Especificación OpenAPI 3.1.0 ejecutable y versionada de los 13 endpoints del backend. |
| **Script de Exportación** | [`scripts/export_openapi.py`](../../scripts/export_openapi.py) | Herramienta automatizada para sincronizar y exportar el esquema OpenAPI desde FastAPI. |
| **Pruebas de Contrato** | [`backend/tests/test_openapi_contract.py`](../../backend/tests/test_openapi_contract.py) | Suite de `pytest` que valida la correspondencia bidireccional API-contrato y la detección de cambios incompatibles. |
| **ADR de Integración** | [`docs/adr/0004-estrategia-integracion-notificaciones.md`](../adr/0004-estrategia-integracion-notificaciones.md) | Decisión y justificación arquitectónica de la integración asíncrona con Firebase Cloud Messaging (FCM). |
| **Pipeline de CI** | [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml) | Ejecución automática de pruebas de contrato en cada `push` y `pull_request`. |
| **C4 Nivel 2 y arc42 §6** | [`docs/c4/context.md`](../c4/context.md) / [`docs/arc42/06_vista_de_ejecucion.md`](../arc42/06_vista_de_ejecucion.md) | Diagramas de contenedores con protocolos/formatos y flujos de ejecución en tiempo de ejecución. |

---

## 2. Contrato de API Versionado (OpenAPI 3.1)

El backend de ROUTB (FastAPI) expone su contrato formalizado bajo el estándar **OpenAPI 3.1.0**, almacenado en `docs/openapi.json`. 

- **Estructura y Cobertura:** Incluye definición exhaustiva de rutas, parámetros, cuerpos de solicitud (`requestBody`) y esquemas de respuesta tipados con Pydantic (`components.schemas` como `UserResponse`, `TripResponse`, `ReservationResponse`, etc.).
- **Trazabilidad de Rutas Principales:**
  - `POST /users/`, `GET /users/` (Gestión de usuarios)
  - `POST /auth/login`, `GET /auth/me` (Autenticación sin estado con JWT)
  - `GET /trips/`, `POST /trips/`, `GET /trips/my-trips`, `GET /trips/{trip_id}`, `POST /trips/{trip_id}/cancel`, `POST /trips/{trip_id}/reservations` (Publicación y reserva atómica de cupos)
  - `GET /requests/trips/{trip_id}`, `POST /requests/{request_id}/accept`, `POST /requests/{request_id}/reject` (Gestión de solicitudes de viaje)
  - `GET /health` (Sondeo de salud de la API)

---

## 3. Estrategia de Integración (ADR-0004)

En el documento [`ADR-0004`](../adr/0004-estrategia-integracion-notificaciones.md) se formaliza la decisión de integrar el servicio de alertas mediante **comunicación asíncrona** con **Firebase Cloud Messaging (FCM)**:

1. **Patrón Asíncrono Basado en Eventos / Tareas en Segundo Plano:** El backend procesa y confirma la transacción de negocio (ej. reserva de cupo o cancelación) y delega el despacho del mensaje a una tarea en segundo plano hacia FCM.
2. **Justificación:** Las llamadas HTTP síncronas bloqueantes hacia proveedores externos introducen acoplamiento temporal y riesgo de fallo en cascada (latencia elevada o caídas temporales de red podrían impedir la reserva o liberar cupos incorrectamente).
3. **Consistencia:** Se asegura desacoplamiento operativo y consistencia eventual para las notificaciones sin comprometer la consistencia transaccional inmediata de la base de datos de ROUTB.

---

## 4. Pruebas de Contrato y Validación en CI

La suite en `backend/tests/test_openapi_contract.py` garantiza la integridad del contrato:

### A. Verificación Bidireccional de la API
Comprueba que cada ruta, método HTTP y código de respuesta prometido en `docs/openapi.json` esté efectivamente implementado en `app.openapi()`, y que todos los esquemas de datos concuerden sin desincronización.

### B. Detección de Cambios Incompatibles (*Breaking Changes*)
El test `test_contract_detects_incompatible_breaking_change` simula la alteración o remoción de un endpoint crítico (`/trips/`). La prueba valida que el verificador detecte la ruptura arrojando un fallo explícito (`AssertionError`), impidiendo que cambios no acordados lleguen a producción.

### C. Integración Continua (GitHub Actions)
En `.github/workflows/ci.yml`, el paso:
```yaml
- name: Ejecutar pruebas unitarias y de contrato OpenAPI
  working-directory: backend
  run: pytest -v
```
ejecuta automáticamente las pruebas en cada commit a las ramas `master` y `Changes`.

---

## 5. Documentación de Arquitectura

- **C4 Nivel 2 (Contenedores):** Cada flecha de interacción está tipificada con su protocolo y formato de transporte:
  - App Móvil $\leftrightarrow$ API Backend: `HTTPS / REST JSON`
  - API Backend $\leftrightarrow$ PostgreSQL: `SQL / asyncpg`
  - API Backend $\rightarrow$ FCM Push Service: `HTTPS / REST JSON (Asíncrono)`
  - FCM Push Service $\rightarrow$ Dispositivos Móviles: `Push / FCM`
- **arc42 Sección 6 (Vista de Ejecución):** Se documentan los escenarios de *Runtime* para Registro de Usuario, Inicio de Sesión y Reserva de Viajes con diagramas de interacción y validación en capas.
