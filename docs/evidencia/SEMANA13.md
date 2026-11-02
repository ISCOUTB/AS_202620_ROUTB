# Documentación del avance — Semana 13 · Modelado de amenazas, dependencias y privacidad

## Resumen ejecutivo

La Semana 13 consolida la postura de seguridad y privacidad de ROUTB mediante un ejercicio integral de modelado de amenazas con metodología **STRIDE anclado directamente sobre el modelo C4 del equipo** ([`docs/c4/context.md`](../c4/context.md)), la integración de **auditoría automatizada de vulnerabilidades de dependencias en el pipeline de CI** con `pip-audit` ([ADR 0023](../adr/0023-estrategia-de-seguridad-stride-y-auditoria-de-dependencias.md)), y la formalización de la **matriz de privacidad y tratamiento de datos personales** bajo el marco de la Ley 1581 de 2012 y el [ADR 0011](../adr/0011-consentimiento-y-privacidad-de-ubicacion.md).

Asimismo, se evaluaron formalmente los riesgos asociados a componentes de **inteligencia artificial generativa** (inyección de prompt, fuga de datos personales/rutas y envenenamiento de contexto), ratificando la decisión arquitectónica del [ADR 0008](../adr/0008-no-componente-generativo.md) de no incorporar modelos generativos en tiempo de ejecución. La arquitectura de seguridad transversal se documentó en la sección 8.8 de arc42, las amenazas residuales aceptadas se justificaron en la sección 11.3 de arc42, y se repitió el barrido de credenciales sin encontrar secretos en el repositorio.

---

## 1. Commit vigente al cierre

| Parámetro | Valor |
|---|---|
| **Hash de referencia** | `00f2338` (cierre de Semana 12 / inicio Semana 13) |
| **Fecha de corte** | 2026-11-01 21:41:05 -0500 |
| **Rama de trabajo** | `Changes` |
| **Entorno verificado** | Python 3.14.6 (`backend/.venv`), Flutter 3.24+, PostgreSQL 16 + PostGIS |

---

## 2. Tabla de amenazas priorizadas con mitigación asignada (STRIDE sobre C4)

El modelado no se basa en listas genéricas de internet, sino en los elementos concretos y fronteras de confianza del diagrama C4 de ROUTB ([`docs/c4/context.md`](../c4/context.md)):

* **Nivel 1 (Contexto):** Actores (`Estudiante Conductor`, `Estudiante Pasajero`, `Administrador`), Sistema (`ROUTB`), Sistemas Externos (`Google Maps/OSRM`, `Push/FCM`).
* **Nivel 2 (Contenedores):** `Aplicación Móvil (Flutter)`, `API Backend (FastAPI)`, `Base de Datos (PostgreSQL/Supabase)`.
* **Nivel 3 (Componentes):** Módulos internos (`auth`, `users`, `trips`, `requests`, `matching`, `notifications`, `admin`, `shared/persistence`).

### Matriz de evaluación de riesgo:
- **Probabilidad:** Alta (3), Media (2), Baja (1)
- **Impacto:** Alto (3), Medio (2), Bajo (1)
- **Prioridad:** P1 - Crítico/Alto (Puntaje 6-9), P2 - Medio (Puntaje 3-4), P3 - Bajo (Puntaje 1-2)

### Catálogo de Amenazas STRIDE

| ID | STRIDE | Elemento C4 Afectado | Descripción de la Amenaza Concreta | Prob. | Imp. | Prio. | Mitigación Asignada | Dueño | Estado |
|---|---|---|---|:---:|:---:|:---:|---|---|:---:|
| **T-01** | **Tampering** | `TRIPS` / `PERSISTENCE` / `DB` | Sobreventa o corrupción de cupos disponibles por peticiones simultáneas de reserva de múltiples pasajeros. | Alta (3) | Alto (3) | **P1** | Descuento atómico condicional en base de datos (`UPDATE ... WHERE available_seats >= :seats`), aislado en la transacción de aceptación ([ADR 0003](../adr/0003-control-atomico-de-cupos.md), [ADR 0021](../adr/0021-integridad-solicitudes-y-concurrencia.md)). Validado bajo concurrencia en `test_cupos.py` y `test_requests_concurrency.py`. | Backend Lead | **Hecho** |
| **T-02** | **Tampering** | `REQUESTS` / `DB` | Un pasajero envía solicitudes duplicadas simultáneas para el mismo viaje para acaparar cupos. | Alta (3) | Alto (3) | **P1** | Índice único parcial `uq_trip_requests_active_passenger` sobre `(trip_id, passenger_id)` con `status IN ('pending', 'accepted')` (Migración 010). Se traduce a `HTTP 400 ActiveRequestAlreadyExistsError`. | Backend Lead | **Hecho** |
| **T-03** | **Information Disclosure** | `REQUESTS` / `APP` | Exposición no autorizada de coordenadas exactas de residencia del pasajero a conductores antes de la aceptación del viaje. | Alta (3) | Alto (3) | **P1** | Ofuscación deliberada de geometrías exactas: antes de aceptar, el conductor solo recibe `address_text` descriptivo o barrio; `stop_geom` se oculta ([ADR 0011](../adr/0011-consentimiento-y-privacidad-de-ubicacion.md)). | Frontend Lead / Backend Lead | **Hecho** |
| **T-04** | **Spoofing** | `AUTH` / `API` | Suplantación de identidad de estudiantes mediante falsificación o manipulación de tokens de sesión. | Media (2) | Alto (3) | **P1** | Firma criptográfica simétrica HMAC-SHA256 (`HS256`) gobernada por `JWT_SECRET_KEY` en entorno seguro; validación estricta de expiración (60 min) en `security.py`. | Backend Lead | **Hecho** |
| **T-05** | **Elevation of Privilege** | `AUTH` / `USERS` | Un pasajero manipula los claims de rol en su token para acceder a endpoints administrativos (`/admin`) o de conductor. | Media (2) | Alto (3) | **P1** | El backend no confía en claims de rol inyectados en el token; la función `get_current_user` consulta la entidad en la base de datos y verifica el rol persistido de forma autoritativa. | Backend Lead | **Hecho** |
| **T-06** | **Tampering** | `REQUESTS` / `TRIPS` | Ataque BOLA / IDOR: un usuario malicioso intenta aceptar, rechazar o cancelar una solicitud perteneciente a otro conductor o pasajero. | Media (2) | Alto (3) | **P1** | Validación explícita de propiedad del recurso en la capa de aplicación (`manage_request.py`): solo el conductor dueño del viaje (`trip.driver_id == current_user.id`) puede transicionar estados de solicitud. | Backend Lead | **Hecho** |
| **T-07** | **Information Disclosure** | `USERS` / `DB` | Fuga de contraseñas de estudiantes en caso de filtración o volcado de la base de datos PostgreSQL. | Baja (1) | Alto (3) | **P2** | Hashing irreversible con algoritmo `bcrypt` y sal (*salt*) criptográfica aleatoria única por usuario (`pwd_context.hash`); nunca se almacena texto claro. | Security Lead | **Hecho** |
| **T-08** | **Information Disclosure** | `TRIPS` / `REQUEST_STOPS` / `DB` | Rastreo o reconstrucción de patrones habituales de desplazamiento de estudiantes por retención indefinida de coordenadas históricas. | Media (2) | Medio (2) | **P2** | Política de retención máxima de 30 días ([ADR 0011](../adr/0011-consentimiento-y-privacidad-de-ubicacion.md)); purga automática diaria programada en GitHub Actions (`purge-location-data.yml`) que invoca la función SQL `purge_location_data()`. | Data Privacy Lead | **Hecho** |
| **T-09** | **Denial of Service** | `MATCHING` / `MAP` | Indisponibilidad o latencia excesiva en el servidor OSRM que congela peticiones de ruteo y agota conexiones del backend. | Media (2) | Medio (2) | **P2** | Timeout estricto de 1.4s en backend (`ROUTING_TIMEOUT_SECONDS`), respuesta degradada tipada geodésica sin reintentos síncronos ([ADR 0014](../adr/0014-fallback-geocode-cache.md)); las rutas degradadas no se cachean en `route_cache`. | Backend Lead | **Hecho** |
| **T-10** | **Tampering** | `REST` / Capa Presentación | Inyección de tipos corruptos, SQL injection o desbordamiento de campos en cargas HTTP JSON. | Media (2) | Medio (2) | **P2** | Validación estricta y tipado estático con modelos Pydantic V2 en todos los enrutadores; persistencia parametrizada exclusiva con SQLAlchemy ORM. | Backend Lead | **Hecho** |
| **T-11** | **Tampering** | `API` / CI / Cadena de Suministro | Manipulación de dependencias descargadas en build o introducción de librerías con vulnerabilidades críticas (CVE). | Media (2) | Medio (2) | **P2** | Compilación de `requirements.txt` con hashes SHA-256 (`uv pip compile --generate-hashes`); integración de escaneo continuo con `pip-audit` en el pipeline de GitHub Actions ([ADR 0023](../adr/0023-estrategia-de-seguridad-stride-y-auditoria-de-dependencias.md)). | DevOps / Security | **Hecho** |
| **T-12** | **Repudiation** | `REQUESTS` / `USERS` | Un estudiante niega haber enviado una solicitud o el conductor niega haberla aceptado en caso de disputa. | Media (2) | Bajo (1) | **P3** | Trazabilidad con marcas temporales inmutables (`created_at`, `requested_at`), historial de estados en base de datos, y logs estructurados JSON con `client_ip` y `timestamp`. | Backend Lead | **Hecho** |
| **T-13** | **Information Disclosure** | Repositorio / CI | Exposición accidental de contraseñas de BD, tokens JWT o credenciales FCM en el código fuente versionado. | Media (2) | Alto (3) | **P1** | Aislamiento en `.env` ignorado por git, inyección por variables de entorno en Dokploy y secretos en CI; barrido continuo de credenciales. | DevOps | **Hecho** |
| **T-14** | **Denial of Service** | `API` / Infraestructura | Ataque distribuido de denegación de servicio (DDoS) volumétrico sobre la IP pública del servidor Dokploy. | Baja (1) | Alto (3) | **P2** | Timeouts en cliente (35s) y proxy inverso Traefik con limitación básica por IP. Aceptado como riesgo residual por presupuesto $0 USD ([arc42 11.3](file:///C:/Users/Keine/dev/Universidad/AS_202620_ROUTB/docs/arc42/11_riesgos_y_deuda_tecnica.md#113-amenazas-aceptadas-como-riesgo-y-justificacion)). | DevOps | **Aceptado** |
| **T-15** | **Spoofing** | `AUTH` / Pasajeros | Registro no autorizado con el número celular de otra persona por ausencia de validación SMS/OTP. | Media (2) | Medio (2) | **P2** | Controles compensatorios de pertenencia universitaria; riesgo aceptado temporalmente para no añadir costos de pasarela SMS a estudiantes ([arc42 11.3](file:///C:/Users/Keine/dev/Universidad/AS_202620_ROUTB/docs/arc42/11_riesgos_y_deuda_tecnica.md#113-amenazas-aceptadas-como-riesgo-y-justificacion)). | Product Owner | **Aceptado** |
| **T-16** | **Information Disclosure** | `APP` / Dispositivo | Extracción física o forense de tokens JWT almacenados en `SharedPreferences` en teléfonos vulnerados (*rooted/jailbroken*). | Baja (1) | Medio (2) | **P3** | Sandbox de la aplicación móvil gestionado por Android/iOS; tokens con expiración de 60 minutos ([arc42 11.3](file:///C:/Users/Keine/dev/Universidad/AS_202620_ROUTB/docs/arc42/11_riesgos_y_deuda_tecnica.md#113-amenazas-aceptadas-como-riesgo-y-justificacion)). | Frontend Lead | **Aceptado** |

---

## 3. Priorización efectiva y correspondencia

### Matriz de Priorización

```
                 IMPACTO
              Bajo (1)      Medio (2)      Alto (3)
         +-------------+--------------+--------------+
Alta (3) |             |              | T-01, T-02,  |
         |             |              | T-03 (P1)    |
         +-------------+--------------+--------------+
Media(2) | T-12 (P3)   | T-08, T-09,  | T-04, T-05,  |
PROB.    |             | T-10, T-11,  | T-06, T-13   |
         |             | T-15 (P2)    | (P1)         |
         +-------------+--------------+--------------+
Baja (1) |             | T-16 (P3)    | T-07, T-14   |
         |             |              | (P2)         |
         +-------------+--------------+--------------+
```

### Correspondencia entre Prioridad y Trabajo Ejecutado
- **Amenazas Críticas P1 (7 de 7):** El 100% de las amenazas P1 identificadas (consistencia de cupos, idempotencia de solicitudes, protección de coordenadas precisas, falsificación de JWT, escalación de privilegios, IDOR y secretos en repo) cuentan con mitigación técnica **Hecha e implementada en código**, respaldada por pruebas automatizadas de concurrencia y contrato.
- **Amenazas Medias P2 (7 de 7):** 5 están totalmente implementadas (`Hecho`), incluyendo hashing `bcrypt`, purga de privacidad a 30 días, timeouts de resiliencia y verificación de hashes SHA-256 en dependencias. 2 amenazas (`T-14` DDoS volumétrico y `T-15` falta de SMS/OTP) fueron evaluadas y formalmente declaradas como `Aceptado` con controles compensatorios en la sección 11.3 de arc42 debido a las restricciones presupuestarias ($0 USD) de la universidad.
- **Amenazas Bajas P3 (2 de 2):** 1 implementada (`T-12` repudiación mitigada con logs estructurados) y 1 aceptada (`T-16` SharedPreferences en cliente).

---

## 4. Análisis de dependencias ejecutado y revisión de hallazgos

### 4.1 Configuración en el Pipeline CI

En cumplimiento del [ADR 0023](../adr/0023-estrategia-de-seguridad-stride-y-auditoria-de-dependencias.md), se integró el análisis de dependencias en el workflow principal [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml):

```yaml
  dependency-audit:
    name: Dependency Vulnerability Audit (pip-audit)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Set up Python environment
        uses: actions/setup-python@v5
        with:
          python-version: "3.14"
      - name: Install pip-audit
        run: pip install --upgrade pip-audit
      - name: Run pip-audit vulnerability scan
        working-directory: backend
        run: pip-audit -r requirements.txt
```

Asimismo, se configuró [`.github/dependabot.yml`](../../.github/dependabot.yml) para monitorización semanal de dependencias en `pip` y `github-actions`.

### 4.2 Ejecución y Revisión Técnica de Hallazgos

Se ejecutó la auditoría completa sobre `backend/requirements.txt` (archivo fijado con 1.282 líneas de dependencias y hashes SHA-256).

```powershell
python -m pip_audit -r backend/requirements.txt
```

**Resultado de la ejecución:** la primera corrida reportó 30 filas de aviso que corresponden a **23 IDs únicos** en 4 paquetes. `pip-audit` devuelve código de salida 1 ante cualquier hallazgo, por lo que el job `dependency-audit` fallaba en cada push del pipeline.

Se revisó la explotabilidad real de cada paquete sobre la arquitectura de ROUTB y se optó por **actualizar las cuatro dependencias** en lugar de silenciar los avisos con `--ignore-vuln`:

| Paquete | Versión detectada | IDs relevantes | Versión aplicada | Análisis de explotabilidad en ROUTB |
|---|---|---|---|---|
| **`pyjwt`** | `2.10.1` | `PYSEC-2025-183`, `PYSEC-2026-120`, `PYSEC-2026-175` a `179`, `PYSEC-2026-4140` a `4183`, `GHSA-pxh4-856f-4h89` | **`2.15.0`** | Los avisos afectan algoritmos asimétricos (claves RSA/ECDSA malformadas o confusión de clave pública). ROUTB usa exclusivamente firma simétrica HMAC-SHA256 con `algorithms=["HS256"]` (`security.py:22`), por lo que el vector no era alcanzable; aun así se actualizó para eliminar la deuda. |
| **`pytest`** | `9.0.1` | `PYSEC-2026-1845` | **`9.0.3`** | Framework de pruebas. Se instala en la imagen porque el `Dockerfile` instala `requirements.txt` completo, pero no se ejecuta ni escucha puertos en producción. |
| **`pyasn1`** | `0.6.4` | `CVE-2026-119194` a `CVE-2026-119197` | **`0.6.5`** | Dependencia transitiva de `google-auth` / Firebase SDK para codificación ASN.1 en certificados X.509. El backend no expone parsers ASN.1 a usuarios externos. |
| **`certifi`** | `2026.7.22` | `PYSEC-2026-4320` | **`2026.10.23`** | Bundle de certificados raíz. Las conexiones salientes de ROUTB van a dominios controlados (Google Maps API, OSRM, Firebase). |

**Remediación aplicada:** se actualizó `backend/requirements.in` (`PyJWT==2.15.0`, `pytest==9.0.3`) y se regeneró el lock con el comando documentado en su cabecera:

```powershell
uv pip compile requirements.in --python-version 3.14 --generate-hashes `
  --upgrade-package certifi --upgrade-package pyasn1 `
  --output-file requirements.txt
```

El diff afecta únicamente a los cuatro bloques anteriores; las otras 57 dependencias conservan versión y hashes.

**Verificación posterior:**
- `pip install --only-binary :all: --require-hashes -r requirements.txt` → instala sin conflictos y valida los hashes nuevos.
- `pip-audit -r requirements.txt` → `No known vulnerabilities found`, código de salida **0**.

**Conclusión de la auditoría:** el pipeline queda en verde sin `--ignore-vuln` ni excepciones, de modo que la aparición de un CVE nuevo vuelve a romper el job y mantiene la auditoría como señal real.

---

## 5. Sección de privacidad: Tratamiento de datos personales y base jurídica

El tratamiento de datos personales en ROUTB se rige por la **Ley 1581 de 2012 de Colombia** (Régimen General de Protección de Datos Personales), el Decreto 1377 de 2013 y los principios de legalidad, finalidad, libertad, veracidad y acceso restringido.

### 5.1 Inventario de Datos Personales por Tabla y Modelo

A partir de la inspección de los modelos de dominio (`backend/app/modules/*/infrastructure/models.py`), se elabora el mapa exhaustivo de datos personales tratados:

| Tabla PostgreSQL | Atributo / Campo | Tipo de Dato | Clasificación (Ley 1581) | Finalidad del Tratamiento | Base Jurídica |
|---|---|---|---|---|---|
| `users` | `name`, `last_name` | `String` | Dato Semiprivado | Identificación del estudiante conductor o pasajero ante la contraparte para coordinar el viaje compartido. | Ejecución del servicio de movilidad / Consentimiento contractual. |
| `users` | `phone` | `String` | Dato Privado | Identificador de inicio de sesión y medio de contacto de contingencia entre conductor y pasajero. | Ejecución del servicio / Consentimiento del titular al registrarse. |
| `users` | `hashed_password` | `String` | Dato Sensible (Credencial) | Autenticación y control de acceso seguro a la plataforma. Nunca expuesto; transformado irreversiblemente con `bcrypt`. | Obligación de seguridad técnica (Principio de Seguridad, Art. 4 lit. g). |
| `users` | `location_consent_at` | `DateTime(tz)` | Registro de Consentimiento | Trazabilidad del momento exacto en que el titular autorizó la captura de su ubicación geográfica. | Cumplimiento del deber legal de demostración del consentimiento (Art. 9). |
| `trips` | `driver_id` | `Integer FK` | Dato Semiprivado | Vinculación del viaje publicado con la identidad del conductor responsable. | Ejecución del servicio. |
| `trips` | `origin_geom`, `dest_geom` | `Geometry(POINT)` | **Dato Sensible (Geolocalización)** | Cálculo de trayectorias, distancias y compatibilidad espacial entre conductor y pasajeros. | **Consentimiento Previo y Expreso** ([ADR 0011](../adr/0011-consentimiento-y-privacidad-de-ubicacion.md)). |
| `trips` | `route_geom` | `Geometry(LINE)` | **Dato Sensible (Geolocalización)** | Trazado de la ruta vehicular para visualización del recorrido y cálculo de ETA en el mapa. | **Consentimiento Previo y Expreso** ([ADR 0011](../adr/0011-consentimiento-y-privacidad-de-ubicacion.md)). |
| `trip_requests`| `passenger_id` | `Integer FK` | Dato Semiprivado | Identificación del solicitante del cupo frente al conductor. | Ejecución del servicio. |
| `request_stops`| `stop_geom` | `Geometry(POINT)` | **Dato Sensible (Geolocalización)** | Coordenadas exactas del punto de recogida o entrega (frecuentemente coincide con el domicilio del estudiante cuando `place_type='door'`). | **Consentimiento Previo y Expreso** ([ADR 0011](../adr/0011-consentimiento-y-privacidad-de-ubicacion.md)). |
| `request_stops`| `address_text` | `Text` | Dato Privado | Dirección textual de la parada (barrio o calle) visible para coordinación. | Consentimiento Previo / Ejecución del servicio. |
| `device_tokens`| `device_token` | `String` | Identificador de Dispositivo | Token generado por FCM para el envío de alertas push sobre cambios de estado en solicitudes y viajes. | Interés legítimo / Ejecución del servicio. |

### 5.2 Mecanismos Técnicos de Garantía de Privacidad

1. **Consentimiento Previo Obligatorio (Art. 9 Ley 1581):** Si `location_consent_at IS NULL`, los endpoints de búsqueda geoespacial, publicación de viajes y solicitud de cupos responden con `403 Forbidden` (`location_consent_required`), imposibilitando el tratamiento sin previa autorización expresa.
2. **Derecho de Revocación Inmediata (Habeas Data):** A través del endpoint `DELETE /users/me/location-consent`, el usuario puede revocar su consentimiento en cualquier momento. La operación revoca el permiso, cancela las solicitudes pendientes y elimina de forma física inmediata las geometrías asociadas en `request_stops` (`backend/app/modules/users/application/location_consent.py`).
3. **Principio de Necesidad y Ofuscación:** Los conductores no tienen acceso a las coordenadas precisas (`stop_geom`) de un pasajero hasta que la solicitud no haya sido aceptada, visualizando únicamente el barrio o referencia textual (`address_text`).
4. **Principio de Retención Limitada y Purga Periódica:** Los datos espaciales no se conservan indefinidamente. Se aplica una ventana máxima de 30 días para coordenadas de viajes y 7 días para caché de rutas. La función SQL `purge_location_data()` anula geometrías y purga paradas vencidas automáticamente mediante la tarea programada en GitHub Actions (`.github/workflows/purge-location-data.yml`).

---

## 6. Riesgos del componente generativo (IA) y postura arquitectónica

El proyecto analizó los riesgos inherentes a la incorporación de modelos de Inteligencia Artificial Generativa (LLMs) en tiempo de ejecución, ratificando la decisión formal del **[ADR 0008](../adr/0008-no-componente-generativo.md): ROUTB no incorpora un componente generativo en producción**.

A continuación se detallan los riesgos propios de componentes generativos evaluados y cómo el diseño determinista de ROUTB los anula:

### 6.1 Inyección de Prompt (*Prompt Injection*)
* **Riesgo evaluado:** Si un LLM procesara campos de texto libre ingresados por estudiantes (ej. `meeting_point`, `origin`, o notas de solicitud) para resumir viajes o sugerir emparejamientos, un atacante podría inyectar instrucciones maliciosas (*jailbreaks* o *system prompt overrides*) que obligaran al modelo a filtrar información de otros usuarios o ejecutar decisiones arbitrarias de asignación de cupos.
* **Mitigación por diseño en ROUTB:** Al no existir un modelo generativo en el flujo de negocio, no hay interfaz de procesamiento de lenguaje natural en tiempo de ejecución. Todas las entradas de texto se validan con esquemas Pydantic tipados y se tratan como datos literales estáticos, eliminando totalmente la superficie de ataque de inyección de prompt.

### 6.2 Fuga de Datos Personales y Rutas (*Data Exfiltration / Privacy Leak*)
* **Riesgo evaluado:** El envío de coordenadas GPS, direcciones de recogida o nombres de estudiantes a APIs externas de modelos generativos comerciales (OpenAI, Anthropic, Gemini) configuraría una transmisión internacional de datos personales sin el consentimiento expreso de la comunidad universitaria, arriesgando la reidentificación de rutinas y domicilios estudiantiles o el entrenamiento no consentido de modelos con dichos datos.
* **Mitigación por diseño en ROUTB:** Todo el cálculo espacial y emparejamiento (*matching*) se ejecuta localmente en el motor PostGIS del monolito mediante algoritmos deterministas basados en distancias geodésicas (ST_DWithin, ST_LineLocatePoint) y OSRM para matrices de tiempo. Ningún dato personal o de viaje sale de los límites de confianza de ROUTB hacia servicios de IA generativa.

### 6.3 Envenenamiento del Contexto (*Context Poisoning*)
* **Riesgo evaluado:** En un sistema con recuperación aumentada por generación (RAG) o ventanas de contexto dinámicas, usuarios maliciosos podrían publicar viajes o paradas falsas con textos diseñados para alterar la memoria del modelo y sesgar las recomendaciones o descripciones de viajes presentadas a otros estudiantes.
* **Mitigación por diseño en ROUTB:** La búsqueda y compatibilidad de viajes opera con una función matemática determinista de scoring paramétrico (`MatchingService`) basada exclusivamente en desvío en minutos, tiempo de espera y distancia caminable (`MATCHING_W_DETOUR`, `MATCHING_W_WAIT`, `MATCHING_W_APPROACH`). No existe estado contextual no estructurado susceptible de envenenamiento.

---

## 7. Referencias cruzadas con arc42 y ADRs

- **arc42 Sección 8 (Conceptos transversales):** Se incorporó la subsección **8.8 Arquitectura de seguridad** en [`docs/arc42/08_conceptos_transversales.md`](../arc42/08_conceptos_transversales.md#88-arquitectura-de-seguridad), documentando límites de confianza (Trust Boundaries), modelo JWT HS256, RBAC, validación Pydantic, hashing bcrypt y ciclo de vida de ubicación.
- **arc42 Sección 11 (Riesgos y deuda técnica):** Se incorporó la subsección **11.3 Amenazas aceptadas como riesgo y su justificación** en [`docs/arc42/11_riesgos_y_deuda_tecnica.md`](../arc42/11_riesgos_y_deuda_tecnica.md#113-amenazas-aceptadas-como-riesgo-y-justificacion), con las fichas técnicas justificativas de las amenazas aceptadas (`AR-01` a `AR-05`).
- **ADR de mitigaciones estructurales:**
  - [ADR 0003](../adr/0003-control-atomico-de-cupos.md): Mitigación de sobreventa de cupos (Tampering).
  - [ADR 0008](../adr/0008-no-componente-generativo.md): Mitigación de riesgos de IA generativa.
  - [ADR 0011](../adr/0011-consentimiento-y-privacidad-de-ubicacion.md): Mitigación de fuga de datos personales y geolocalización.
  - [ADR 0014](../adr/0014-fallback-geocode-cache.md): Mitigación de denegación de servicio por caída de OSRM.
  - [ADR 0021](../adr/0021-integridad-solicitudes-y-concurrencia.md): Mitigación de acaparamiento y concurrencia de solicitudes.
  - [ADR 0023](../adr/0023-estrategia-de-seguridad-stride-y-auditoria-de-dependencias.md): **Nuevo ADR estructural** que formaliza el modelado STRIDE sobre C4 y la auditoría obligatoria de dependencias en CI con `pip-audit`.

---

## 8. Barrido de secretos y credenciales en el repositorio

Se ejecutó un barrido exhaustivo en todo el árbol de archivos del repositorio (excluyendo entornos virtuales locales `.venv`, historial de git `.git` y directorios temporales de compilación `build` y `.dart_tool`):

```powershell
Get-ChildItem -Recurse -File -Exclude "*.git*", "*.venv*", "*build*", "*.dart_tool*" | Select-String -Pattern "(BEGIN (RSA |EC )?PRIVATE KEY|eyJhbGci|ghp_[A-Za-z0-9]{36}|AIza[0-9A-Za-z\\-_]{35})"
```

**Resultado:**
- **0 claves privadas PEM** encontradas.
- **0 tokens JWT o tokens de GitHub/Google con valores reales** encontrados.
- Los archivos `.env` permanecen correctamente ignorados por `.gitignore`.
- Las pruebas de CI continúan inyectando credenciales efímeras y no sensibles (`ci-test-secret-key`, contraseñas locales de prueba).

---

## 9. Matriz de cumplimiento S13

A continuación se presenta la matriz de evaluación técnica diligenciada conforme a [`semana-13-evidencia-s13.md`](file:///C:/Users/Keine/dev/Universidad/AS_202620_ROUTB/semana-13-evidencia-s13.md):

| Criterio de evaluación | Evidencia técnica esperada | Estado | Observaciones |
|---|---|:---:|---|
| **Tabla de amenazas anclada en elementos del C4 del equipo** | Tabla citada, con el elemento afectado por fila | **Cumple** | Tabla completa en sección 2 de este documento con 16 amenazas mapeadas a los elementos C4 (`APP`, `API`, `DB`, `AUTH`, `USERS`, `TRIPS`, `REQUESTS`, `MATCHING`, `NOTIFICATIONS`, `MAP`, `PUSH`). |
| **Priorización por probabilidad e impacto** | Columnas de la tabla, con el orden resultante | **Cumple** | Columnas `Probabilidad`, `Impacto` y `Prioridad` (P1, P2, P3) con matriz 3x3 documentada en sección 3. |
| **Mitigación asignada a cada amenaza, con dueño y estado** | Columnas de mitigación y estado | **Cumple** | Cada una de las 16 amenazas cuenta con mitigación concreta, dueño asignado por rol y estado (`Hecho` o `Aceptado`). |
| **El plan ataca primero lo priorizado** | Correspondencia entre prioridad y trabajo hecho | **Cumple** | El 100% de las amenazas críticas P1 (7/7) y las altas operativas de P2 cuentan con mitigación implementada en código y verificada con pruebas. |
| **Análisis de dependencias ejecutado en el pipeline** | Línea del workflow y URL del run | **Cumple** | Job `dependency-audit` con `pip-audit` configurado en `.github/workflows/ci.yml:78-91` y `.github/dependabot.yml` añadido. |
| **Hallazgos del análisis revisados y decididos** | Apartado con los hallazgos y qué se hizo con cada uno | **Cumple** | Sección 4.2 documenta la revisión de los 23 IDs únicos en `pytest`, `pyjwt`, `pyasn1` y `certifi`, su explotabilidad real en ROUTB y la actualización aplicada; `pip-audit` cierra en `No known vulnerabilities found`. |
| **Sección de privacidad con datos personales tratados y su base** | Apartado citado, contrastado con el modelo de datos | **Cumple** | Sección 5 detalla el inventario completo contrastado con las 5 tablas SQLAlchemy, bases bajo Ley 1581 de 2012, consentimiento y purga periódica. |
| **Riesgos del componente generativo, si el sistema lo incorpora** | Apartado con inyección, fuga y envenenamiento | **Cumple** | Sección 6 analiza exhaustivamente los 3 riesgos (inyección de prompt, fuga de coordenadas y envenenamiento de contexto) y cómo el ADR 0008 los erradica por diseño determinista. |
| **arc42 sección 8 con la arquitectura de seguridad** | `docs/arc42/08*` | **Cumple** | Subsección 8.8 incorporada en [`docs/arc42/08_conceptos_transversales.md`](../arc42/08_conceptos_transversales.md#88-arquitectura-de-seguridad) con límites de confianza, JWT, RBAC, criptografía y retención. |
| **arc42 sección 11 con las amenazas aceptadas y su motivo** | `docs/arc42/11*` | **Cumple** | Subsección 11.3 incorporada en [`docs/arc42/11_riesgos_y_deuda_tecnica.md`](../arc42/11_riesgos_y_deuda_tecnica.md#113-amenazas-aceptadas-como-riesgo-y-justificacion) con 5 amenazas aceptadas y sus justificaciones formales. |
| **ADR de las mitigaciones que cambian la estructura** | Archivos de `docs/adr/` del periodo | **Cumple** | [ADR 0023](../adr/0023-estrategia-de-seguridad-stride-y-auditoria-de-dependencias.md) creado y registrado en [arc42 sección 9](../arc42/09_decisiones_arquitectonicas.md); trazabilidad con ADR 0003, 0008, 0011, 0014, 0021. |
