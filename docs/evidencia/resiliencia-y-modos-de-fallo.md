# Evidencia de Resiliencia, Modos de Fallo y Decisión de Extracción

Este documento consolida la línea base, la tabla de modos de fallo, el análisis de idempotencia y saga, y la verificación de los 9 criterios de evaluación para la resiliencia e integración de ROUTB.

<<<<<<< HEAD
> **Nota de vigencia:** este documento conserva la evidencia del commit
> `fe82eac4ab1a9f54dbacc40b8b99a6c5322b309c`. La geocodificación del cliente
> cambió con el [ADR 0018](../adr/0018-google-maps-platform-frontend.md); las
> referencias a Nominatim y OSRM describen el estado auditado, no el flujo
> actual.

=======
>>>>>>> origin/master
---

## 1. Línea base en el repositorio (Criterio 1)

### 1.1 Identificación del commit y entorno de entrega

- **Rama de trabajo activa:** `Changes`
- **Hash del commit de entrega:** `fe82eac4ab1a9f54dbacc40b8b99a6c5322b309c`
- **Fecha del commit:** `Fri Oct 16 23:32:02 2026 -0500`

### 1.2 Ejecución de los greps de la actividad

#### Grep 1 — Dónde está la integración principal

Comando ejecutado:
```bash
git grep -nE "http\.(Client|get|post|patch|delete)|ApiClient" -- frontend backend
```

Evidencia técnica de salida:
- `frontend/lib/core/network/api_client.dart:16`: `class ApiClient { ... }` — cliente HTTP centralizado de la aplicación cliente Flutter.
- `frontend/lib/core/network/api_client.dart:46`: Invocación `_client.get(...)`.
- `frontend/lib/core/network/api_client.dart:60`: Invocación `_client.post(...)`.
- `frontend/lib/core/network/api_client.dart:75`: Invocación `_client.patch(...)`.
- `frontend/lib/core/network/api_client.dart:86`: Invocación `_client.delete(...)`.
- `frontend/lib/features/trips/data/trip_repository.dart:33-35`: Consumo de `ApiClient` para interactuar con los módulos `/trips` y `/requests`.
- `frontend/lib/features/auth/data/auth_repository.dart:23-25`: Consumo de `ApiClient` para autenticación y gestión de usuarios.
- `frontend/lib/core/map/place_locator.dart:22-25`: `http.Client` para resolución de geolocalización con Nominatim y OSRM.

#### Grep 2 — Qué mitigaciones existen de verdad

Comando ejecutado:
```bash
git grep -niE "timeout|retry|circuit|fallback|backoff" -- frontend backend
```

Evidencia técnica de salida:
- `frontend/lib/core/network/api_client.dart:26`: `static const Duration timeout = Duration(seconds: 35);` — timeout explícito con margen holgado para redes móviles lentas y esperas prolongadas del backend.
- `frontend/lib/core/network/api_client.dart:139`: `response = await request().timeout(timeout);` — aplicación de timeout sobre cada solicitud.
- `frontend/lib/core/network/api_client.dart:140-152`: Captura de `TimeoutException`, `SocketException`, `http.ClientException` y mapeo a `ApiException` con mensajes descriptivos.
- `frontend/lib/features/passenger/screens/passenger_screen.dart:371-374, 411`: Mitigación interactiva en UI mediante el widget `_TripsFailed` (definido en `:768-794`) y los callbacks `onRetry: _load` / `onRetry: _loadMyRequests`.
- `frontend/lib/core/map/place_locator.dart:24, 106, 135`: `timeout = Duration(seconds: 8)` aplicado a las consultas, con fallback al catálogo local (`catalogPoint`, `:70-78`).
- `backend/app/modules/requests/application/create_request.py:58-68`: Verificación contra duplicidad de solicitudes activas para un mismo viaje y pasajero (`ActiveRequestAlreadyExistsError`).

### 1.3 Estado inicial en la documentación del repositorio

- En `docs/adr/`: Existían los ADR 0001 a 0016, entre ellos el 0001 (monolito modular), el 0003 (control atómico de cupos), el 0004 (integración síncrona REST) y el 0015 (plataforma de despliegue vigente). No existía un ADR que formalizara la evaluación técnica de extracción de módulos a microservicios.
- En `docs/arc42/11_riesgos_y_deuda_tecnica.md`: Registraba riesgos genéricos y deuda técnica organizativa, pero no incluía los modos de fallo de red de la integración síncrona cliente-servidor ni la deuda técnica de idempotencia y reintentos automáticos de esa integración.
- En `docs/aspectos.md`: Contenía 9 aspectos, sin una fila dedicada a la resiliencia, tolerancia a fallos y modos de fallo de la integración cliente-backend.

### 1.4 Integración elegida

Se selecciona formalmente la **integración síncrona REST/JSON sobre HTTPS entre el cliente móvil Flutter (`ApiClient`) y el backend FastAPI**, enfocada en el flujo crítico de **solicitudes y reservas de cupos** (`requests` y `trips`), respaldado por la base de datos PostgreSQL.

### 1.5 Lista de "Implementado" vs "Pendiente"

| Clasificación | Elemento / Mitigación | Ubicación en código / Plan |
|---|---|---|
| **Implementado** | Timeout de 35 segundos en cliente HTTP | `frontend/lib/core/network/api_client.dart:26, 139` |
| **Implementado** | Normalización de excepciones de red y timeout a `ApiException` | `frontend/lib/core/network/api_client.dart:140-152` |
| **Implementado** | Reintento manual interactivo desde la UI ante fallo | `frontend/lib/features/passenger/screens/passenger_screen.dart:371-374, 411` |
| **Implementado** | Bloqueo en base de datos de solicitudes duplicadas activas | `backend/app/modules/requests/application/create_request.py:58-68` |
| **Implementado** | Transición de estado idempotente en aceptación/rechazo | `backend/app/modules/requests/application/manage_request.py:50-51, 166-167` |
| **Implementado** | Control atómico condicional de cupos en SQL | `backend/app/modules/trips/application/request_seats.py:47-59, 62-73` |
| **Pendiente** | Clave de idempotencia (`Idempotency-Key` en cabecera HTTP) con almacenamiento temporal en backend | Plan: Middleware en FastAPI con registro de hash UUID v4 por 60 s (Fecha prevista: Q1 2027) |
| **Pendiente** | Reintento automático con retroceso exponencial (*backoff*) y fluctuación (*jitter*) en lecturas GET | Plan: Interceptor en `ApiClient` con 3 intentos máximos para peticiones seguras (Fecha prevista: Q1 2027) |
| **Pendiente** | Interruptor de circuito (*Circuit Breaker*) en cliente móvil | Plan: Estado de circuito en `ApiClient` tras 5 fallos consecutivos y enfriamiento de 30 s (Fecha prevista: Q2 2027) |

---

## 2. Tabla de modos de fallo (Criterios 2, 3 y 4)

| Modo de fallo | ¿Qué pasa en esta integración? | Mitigación concreta | Estado |
|---|---|---|---|
| **No responde** *(Criterio 2)* | El backend FastAPI está apagado o inaccesible (mantenimiento o caída del contenedor en Dokploy), o el dispositivo móvil no tiene conectividad a internet. La petición HTTP no recibe respuesta del servidor, lanzando `SocketException` o agotando el tiempo límite. | 1. **Implementado:** Timeout de 35 s en `frontend/lib/core/network/api_client.dart:26, 139` que interrumpe la espera infinita.<br>2. **Implementado:** Captura de `SocketException` y `TimeoutException` con traducción unificada a `ApiException` descriptiva en `frontend/lib/core/network/api_client.dart:140-145`.<br>3. **Implementado:** Componente visual `_TripsFailed` con botón de reintento interactivo (`onRetry`) en `frontend/lib/features/passenger/screens/passenger_screen.dart:371-374, 768-794`.<br>4. **Pendiente:** Implementar *Circuit Breaker* en el cliente Flutter para cortar tráfico tras 5 fallos consecutivos durante 30 segundos (Plan: Q2 2027). | **Implementado** (`frontend/lib/core/network/api_client.dart:26`, `frontend/lib/features/passenger/screens/passenger_screen.dart:371`) / **Pendiente** (Circuit Breaker, Q2 2027) |
| **Responde tarde** *(Criterio 3)* | El backend tarda más de lo habitual en responder por congestión del contenedor o de la base de datos, o por una red móvil lenta. Un timeout del cliente demasiado estricto (ej. 5 o 10 s) abortaría llamadas que sí habrían terminado con éxito. | 1. **Implementado:** Margen de espera holgado de 35 s configurado en `frontend/lib/core/network/api_client.dart:26` (`static const Duration timeout = Duration(seconds: 35)`).<br>2. **Implementado:** Indicadores visuales de carga (`CircularProgressIndicator`) y bloqueo del botón de reserva mientras la petición está en vuelo (`frontend/lib/features/passenger/screens/passenger_screen.dart:251, 736`).<br>3. **Pendiente:** Notificación visual progresiva al estudiante si la espera supera los 15 segundos ("La conexión está tardando...") (Plan: Q1 2027). | **Implementado** (`frontend/lib/core/network/api_client.dart:26`) / **Pendiente** (Aviso proactivo de espera, Q1 2027) |
| **Responde dos veces / Petición duplicada** *(Criterio 4)* | El usuario pulsa repetidamente el botón de solicitar cupo o la aplicación reintenta la solicitud tras un corte de red cuando el servidor ya había insertado el registro en base de datos. Sin protección, se crearían solicitudes duplicadas o se descontarían cupos dos veces. | 1. **Implementado:** Verificación previa de unicidad en base de datos en `backend/app/modules/requests/application/create_request.py:58-68`, que comprueba si existe una solicitud activa (`pending` o `accepted`) para la combinación `(trip_id, passenger_id)` y aborta con `ActiveRequestAlreadyExistsError` (HTTP 400).<br>2. **Implementado:** En transiciones de estado (`accept_request` y `reject_request`), si la solicitud ya se encuentra en el estado meta, retorna la instancia sin aplicar mutaciones adicionales de cupos (`backend/app/modules/requests/application/manage_request.py:50-51, 166-167`).<br>3. **Implementado:** Bloqueo del botón de reserva mientras hay un envío en curso (`frontend/lib/features/passenger/screens/passenger_screen.dart:251, 736`).<br>4. **Pendiente:** Incorporar cabecera `Idempotency-Key` en peticiones mutantes y middleware de idempotencia en FastAPI para responder con el mismo resultado persistido (Plan: Q1 2027). | **Implementado** (`backend/app/modules/requests/application/create_request.py:58-68`, `backend/app/modules/requests/application/manage_request.py:50-51, 166-167`) / **Pendiente** (Idempotency-Key, Q1 2027) |

---

## 3. Idempotencia y análisis de Saga (Criterio 5)

### 3.1 Identificación de operaciones mutantes y repetibles

En la integración entre la aplicación móvil y el backend existen cuatro operaciones mutantes sobre las solicitudes de cupos:

1. **Creación de solicitud:** `POST /requests/trips/{trip_id}`
2. **Aceptación de solicitud por el conductor:** `PATCH /requests/{request_id}/accept`
3. **Rechazo de solicitud por el conductor:** `PATCH /requests/{request_id}/reject`
4. **Retiro o cancelación de solicitud por el pasajero:** `DELETE /requests/{request_id}`

### 3.2 Idempotencia en la implementación actual

La arquitectura actual implementa idempotencia a nivel de modelo de dominio y transiciones de estado en base de datos relacional:

- **En la creación de solicitudes (`create_request.py:58-68`):**
  Aplica semántica de **rechazo seguro**. Si la petición se repite con los mismos parámetros `(trip_id, passenger_id)`, el backend detecta el registro preexistente en estado `pending` o `accepted` y lanza `ActiveRequestAlreadyExistsError`, evitando crear un segundo registro o consumir cupos dos veces.
- **En la aceptación de solicitudes (`manage_request.py:50-51`):**
  Aplica **idempotencia condicional**. Si una solicitud ya fue aceptada (`request.status == "accepted"`), la función retorna inmediatamente la solicitud sin invocar `reserve_request_seats`, garantizando que los cupos no se resten nuevamente. Si compite concurrentemente, la sentencia SQL `update(TripRequest).where(TripRequest.id == request_id, TripRequest.status == "pending")` (`manage_request.py:77-88`) garantiza que exactamente una ejecución obtenga `rowcount == 1`.
- **En el rechazo de solicitudes (`manage_request.py:166-167`):**
  Si el estado ya es `rejected`, retorna la entidad sin efectos colaterales.
- **En el retiro de solicitudes (`manage_request.py:217-227`):**
  Ejecuta una eliminación con retorno (`delete(TripRequest)...returning(...)`). La primera llamada retira el registro y libera cupos; una segunda llamada repetida obtiene `removed is None` y responde con 404 (`TripRequestNotFoundError`), impidiendo que se liberen cupos más de una vez.

### 3.3 Especificación de la clave de idempotencia (`Idempotency-Key`)

Para cubrir el escenario donde la red falla en el trayecto de regreso (el servidor procesó la creación exitosamente con 201, pero el cliente recibió un timeout y reintenta), se formaliza la siguiente especificación técnica:

1. **Cliente (`ApiClient`):** En cada petición `POST` o `PATCH` mutante, genera un identificador único universal (UUID v4) y lo envía en la cabecera HTTP:
   ```http
   Idempotency-Key: 7b84d12c-9a3e-4b21-8f19-32a106f37cb2
   ```
2. **Backend (FastAPI):**
   - Un middleware intercepta la cabecera antes del enrutamiento.
   - Si la clave ya fue procesada exitosamente en los últimos 60 segundos, retorna directamente la respuesta almacenada en caché con el mismo código de estado (201 o 200) y el cuerpo JSON original.
   - Si la clave está actualmente en proceso, responde con código `409 Conflict` ("Petición en curso").
   - Si es la primera vez que se recibe, ejecuta el caso de uso y persiste la clave junto con el código y payload resultante.

### 3.4 Análisis del patrón Saga (¿Por qué no aplica hoy y cómo aplicaría si se distribuyera?)

- **¿Por qué no aplica hoy?**
  ROUTB opera como un **monolito modular** ([ADR 0001](../adr/0001-usar-monolito-modular.md)) con una única base de datos PostgreSQL ([ADR 0006](../adr/0006-base-de-datos-supabase.md)). La coordinación entre la entidad `TripRequest` (módulo `requests`) y el inventario de cupos de `Trip` (módulo `trips`) se ejecuta dentro de una **transacción local ACID**. Si la reserva de cupos falla, se ejecuta `db.rollback()` (por ejemplo, en `manage_request.py:91`), regresando el estado del sistema de forma atómica y sin necesidad de mensajes compensatorios asíncronos.
- **Diseño de Saga orquestada en caso de microservicios futuros:**
  Si en el futuro se extrajera `requests` como microservicio independiente, se requeriría una Saga orquestada con las siguientes acciones y compensaciones:

```
[Paso 1: Solicitud Creada]
  requests-service crea TripRequest en estado PENDING_RESERVATION
      │
      ▼
[Paso 2: Reserva de Cupos]
  Llamada HTTP/gRPC a trips-service para descontar cupos
      │
      ├──> Éxito: requests-service actualiza estado a CONFIRMED
      │
      └──> Fallo / Timeout: Compensación
           trips-service revierte reserva (si aplicó)
           requests-service marca solicitud como REJECTED_CAPACITY
```

---

## 4. ADR de extracción (Criterios 6 y 7)

La evaluación de extracción se encuentra formalizada en el [ADR 0017: Decisión sobre la extracción del módulo de solicitudes y reservas (requests) a microservicio independiente](../adr/0017-decision-extraccion-modulo-requests.md).

### Resumen de la decisión y criterios evaluados

- **Decisión adoptada:** **NO EXTRAER** el módulo `requests`. Mantener la arquitectura de monolito modular ([ADR 0001](../adr/0001-usar-monolito-modular.md)).
- **Criterios reales aplicados:**
  1. *Tamaño del equipo:* 4 estudiantes universitarios; el sobrecosto de gestionar múltiples repositorios, pipelines, contratos y observabilidad distribuida comprometería el avance del proyecto.
  2. *Acoplamiento de datos:* `requests` y `trips` requieren consistencia atómica para garantizar 0 % de sobreventa en cupos concurrentes ([ADR 0003](../adr/0003-control-atomico-de-cupos.md)). Mantenerlos en la misma base de datos permite transacciones ACID locales y evita transacciones distribuidas.
  3. *Frecuencia de cambio:* Ambos módulos se modifican y despliegan juntos en los mismos cortes y versiones.
  4. *Costo operativo:* El límite presupuestario es estricto de $0.00 USD ([ADR 0005](../adr/0005-render-plataforma-de-despliegue.md) y [ADR 0015](../adr/0015-dokploy-plataforma-de-despliegue.md)). Alojar dos o más servicios independientes superaría la cuota gratuita o duplicaría los *cold starts*.

---

## 5. Actualización en arc42 sección 11 y matriz de aspectos (Criterios 8 y 9)

### 5.1 arc42 sección 11 (Riesgos y deuda técnica)

Se actualizó [docs/arc42/11_riesgos_y_deuda_tecnica.md](../arc42/11_riesgos_y_deuda_tecnica.md):
- **11.1 Riesgos del sistema:** Se añadieron los tres modos de fallo identificados (No responde, Responde tarde y Petición duplicada) con su impacto, probabilidad y mitigaciones implementadas en código.
- **11.2 Deuda técnica:** Se incorporaron formalmente como deuda técnica las tres mitigaciones pendientes (clave de idempotencia en mutaciones, reintentos automáticos con backoff/jitter en lecturas, e interruptor de circuito en cliente).

### 5.2 docs/aspectos.md

Se actualizó [docs/aspectos.md](../aspectos.md) incorporando el **Aspecto 10**:
- **Aspecto:** Resiliencia y modos de fallo en la integración cliente-servidor.
- **Requisito:** La comunicación cliente-servidor para solicitudes de cupos debe mitigar caídas de red, arranques en frío y peticiones duplicadas sin generar sobreventa ni pérdida de consistencia (Disponibilidad, Rendimiento, Consistencia).
- **C4:** [Nivel 2 Contenedores](../c4/context.md).
- **ADR:** [ADR 0004](../adr/0004-integracion-sincrona-rest.md) y [ADR 0017](../adr/0017-decision-extraccion-modulo-requests.md).
- **Código:** `frontend/lib/core/network/api_client.dart` y `backend/app/modules/requests/application/manage_request.py`.
- **Pruebas:** `backend/tests/test_requests_flow.py` y `backend/tests/test_cupos.py`.
- **Evidencia:** `docs/evidencia/resiliencia-y-modos-de-fallo.md` y `docs/arc42/11_riesgos_y_deuda_tecnica.md`.

---

## 6. Verificación de existencia de rutas citadas

Todas las rutas citadas a lo largo de este documento y de los artefactos relacionados han sido verificadas en el árbol del proyecto:

1. `frontend/lib/core/network/api_client.dart` (Existe: timeout 35 s, manejo de excepciones).
2. `frontend/lib/features/passenger/screens/passenger_screen.dart` (Existe: reintento manual `onRetry`).
3. `backend/app/modules/requests/application/create_request.py` (Existe: control de solicitud duplicada).
4. `backend/app/modules/requests/application/manage_request.py` (Existe: transiciones idempotentes y rollback transaccional).
5. `backend/app/modules/trips/application/request_seats.py` (Existe: actualización atómica condicional de cupos).
6. `docs/adr/0017-decision-extraccion-modulo-requests.md` (Creado).
7. `docs/arc42/09_decisiones_arquitectonicas.md` (Actualizado con ADR 0017).
8. `docs/arc42/11_riesgos_y_deuda_tecnica.md` (Actualizado con riesgos y deuda técnica de integración).
9. `docs/aspectos.md` (Actualizado con fila Aspecto 10).
10. `docs/evidencia/resiliencia-y-modos-de-fallo.md` (Creado).

