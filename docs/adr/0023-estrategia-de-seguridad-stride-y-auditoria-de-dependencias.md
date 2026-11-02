# ADR 0023: Estrategia de seguridad, modelado de amenazas STRIDE y auditoría automatizada de dependencias

## Estado

Aceptado.

## Contexto

ROUTB gestiona la movilidad colaborativa de la comunidad universitaria de la UTB, tratando datos de identidad de estudiantes, credenciales, puntos geográficos de origen y destino, y disponibilidad transaccional de cupos en tiempo real. 

A medida que el monolito modular y sus integraciones (Google Maps, OSRM, Firebase Cloud Messaging) han madurado, se hace indispensable:
1. Formalizar un marco de modelado de amenazas sistemático anclado en los elementos arquitectónicos concretos del modelo C4 ([`docs/c4/context.md`](../c4/context.md)), superando listas genéricas no contextualizadas.
2. Garantizar la integridad de la cadena de suministro de software (*software supply chain security*) mediante la verificación automatizada y continua de vulnerabilidades conocidas (CVE) en las dependencias de producción.
3. Establecer controles verificables en la integración continua (CI) que eviten la introducción de librerías vulnerables o configuraciones inseguras.

## Decisión

Se adopta una **estrategia de seguridad integral basada en el modelo STRIDE y auditoría automatizada continua**:

### 1. Marco de Modelado de Amenazas STRIDE sobre el Diagrama C4

Se adopta la metodología **STRIDE** (Spoofing, Tampering, Repudiation, Information Disclosure, Denial of Service, Elevation of Privilege) aplicada de forma directa sobre cada contenedor y componente definido en el C4 de ROUTB:

* **Nivel 1 (Contexto):** Amenazas en las interacciones entre los actores (`Estudiante Conductor`, `Estudiante Pasajero`, `Administrador`), el sistema `ROUTB` y los servicios externos (`Mapas/Google Maps/OSRM`, `Push/FCM`).
* **Nivel 2 (Contenedores):** Amenazas en los canales de comunicación y límites de confianza entre `Aplicación Móvil (Flutter)`, `API Backend (FastAPI)` y `Base de Datos (PostgreSQL/Supabase)`.
* **Nivel 3 (Componentes):** Amenazas en los módulos internos (`auth`, `users`, `trips`, `requests`, `matching`, `notifications`, `admin`, `shared/persistence`).

Cada amenaza identificada debe contar obligatoriamente con:
- Identificador y categoría STRIDE.
- Elemento C4 específico afectado.
- Valoración de probabilidad e impacto (matriz de riesgo).
- Mitigación técnica concreta implementada o planificada.
- Rol responsable (dueño).
- Estado explícito (`Hecho`, `Pendiente`, `Aceptado como riesgo`).

### 2. Auditoría Automatizada de Dependencias en el Pipeline CI

Para mitigar riesgos de vulnerabilidades en librerías de terceros (OWASP Top 10 A06:2021 - *Vulnerable and Outdated Components*):

1. **Herramienta en CI:** Se integra **`pip-audit`** como un job independiente (`dependency-audit`) en `.github/workflows/ci.yml`.
2. **Alcance:** El escáner audita `backend/requirements.txt`, cuyas dependencias se encuentran fijadas con hashes criptográficos SHA-256 generados mediante `uv`.
3. **Bloqueo y reporte:** Si se detecta una vulnerabilidad con CVE publicado, el pipeline reporta el hallazgo para evaluación técnica inmediata.
4. **Dependabot:** Se habilita `.github/dependabot.yml` con revisiones semanales automáticas de dependencias de Python y GitHub Actions.

### 3. Criterio de Aceptación de Amenazas Residuales

Cualquier amenaza que no cuente con una mitigación activa inmediata debe ser clasificada como `Aceptada como riesgo` en la sección 11.3 de arc42, acompañándose de:
- Justificación técnica o económica explícita (ej. coherencia con el presupuesto $0 USD o limitación de latencia p95 < 3.99 s).
- Controles compensatorios activos (timeouts, validaciones Pydantic, transacciones ACID).
- Condiciones o métricas bajo las cuales la decisión deberá revaluarse.

## Consecuencias

### Positivas
- Trazabilidad directa entre la arquitectura de software (C4), las amenazas identificadas y los mecanismos de código implementados.
- Detección temprana y automática de vulnerabilidades en el ecosistema de dependencias en cada Pull Request y push a ramas protegidas.
- Claridad contractual sobre qué riesgos asume la organización y cuáles están mitigados por diseño.
- Cumplimiento de los estándares de seguridad de software y normativas de privacidad (Ley 1581 de 2012).

### Negativas / Costes asumidos
- Añade un tiempo adicional mínimo (~15 a 30 segundos) al tiempo total de ejecución del workflow de GitHub Actions.
- Requiere mantenimiento periódico y evaluación de alertas de Dependabot o advisories de seguridad.

## Trazabilidad y referencias

| Elemento | Ubicación |
|---|---|
| Diagrama C4 del sistema | [`docs/c4/context.md`](../c4/context.md) |
| Arquitectura de seguridad arc42 | [`docs/arc42/08_conceptos_transversales.md`](../arc42/08_conceptos_transversales.md#88-arquitectura-de-seguridad) |
| Amenazas aceptadas arc42 | [`docs/arc42/11_riesgos_y_deuda_tecnica.md`](../arc42/11_riesgos_y_deuda_tecnica.md#113-amenazas-aceptadas-como-riesgo-y-justificacion) |
| Workflow de CI con pip-audit | [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml) |
| Configuración de Dependabot | [`.github/dependabot.yml`](../../.github/dependabot.yml) |
| Evidencia consolidada S13 | [`docs/evidencia/SEMANA13.md`](../evidencia/SEMANA13.md) |
| ADR relacionados | [ADR 0003](0003-control-atomico-de-cupos.md), [ADR 0008](0008-no-componente-generativo.md), [ADR 0011](0011-consentimiento-y-privacidad-de-ubicacion.md), [ADR 0021](0021-integridad-solicitudes-y-concurrencia.md) |
