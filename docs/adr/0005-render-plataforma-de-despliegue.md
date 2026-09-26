# 0005 - Elección de plataforma para el despliegue del backend (Render Web Service)

## Estado

Aceptado

## Contexto

ROUTB requiere una plataforma de cómputo y hosting en la nube para ejecutar el contenedor del backend desarrollado con FastAPI (Python 3.14). El servicio debe ser públicamente accesible mediante HTTPS desde fuera de la red de la universidad y permitir la verificación continua de endpoints de diagnóstico y negocio.

El proyecto está sujeto a restricciones académicas y organizativas estrictas:
- **Presupuesto cero ($0.00 USD):** No existe partida presupuestaria para infraestructura en la nube.
- **Sin tarjeta de crédito:** Ningún integrante del equipo dispone de tarjeta de crédito para asociar a proveedores cloud, ni se asume el riesgo de cobros automáticos o facturación imprevista.
- **Soporte de estándares abiertos:** Debe ejecutar un contenedor OCI / Docker estándar definido en `backend/Dockerfile`.
- **Automatización e Infraestructura como Código (IaC):** Debe permitir despliegue automatizado vinculado al repositorio de GitHub mediante un manifiesto versionado.

## Decisión

Se adopta **Render (Free Web Service)** como plataforma de cómputo y despliegue del backend de ROUTB:

1. **Despliegue basado en Docker:** El servicio se construye directamente a partir de `backend/Dockerfile` versionado en el repositorio, ejecutándose con un usuario sin privilegios (`appuser`).
2. **Infraestructura como Código:** La configuración del servicio se formaliza en el manifiesto `render.yaml`, especificando el plan gratuito y proporcionando las variables de entorno.
3. **Terminación TLS/HTTPS automática:** Render proporciona certificados SSL gestionados sin costo adicional bajo el subdominio `https://as-202620-routb.onrender.com`.

## Alternativas consideradas

### Railway
- **Ventajas:** Despliegue intuitivo y soporte nativo de Docker.
- **Motivo de descarte:** Su modelo de capa gratuita es temporal (crédito único no renovable de $5 USD o límite de 30 días de prueba). Al agotarse el crédito o cumplirse el mes, los servicios se suspenden a menos que se introduzca una tarjeta de crédito, lo cual imposibilita la operación durante todo el semestre académico.

### Fly.io
- **Ventajas:** Excelente latencia global y manejo eficiente de micro-máquinas Firecracker.
- **Motivo de descarte:** Exige obligatoriamente una tarjeta de crédito válida para verificar la cuenta antes de permitir crear o desplegar aplicaciones, violando directamente la restricción de ausencia total de instrumentos financieros.

### AWS Elastic Beanstalk / Google Cloud Run / Microsoft Azure App Service
- **Ventajas:** Ecosistemas empresariales líderes con alta escalabilidad.
- **Motivo de descarte:** Todos exigen registro con tarjeta de crédito para la activación de la cuenta. Además, presentan un alto riesgo de facturación imprevista si se excede el tráfico o culminan periodos de gracia.

## Consecuencias

### Positivas
- Cumplimiento estricto del presupuesto: costo mensual recurrente de **$0.00 USD**.
- Cero requisitos de tarjetas de crédito o instrumentos bancarios para el registro y operación.
- Despliegue reproducible y versionado a través de `backend/Dockerfile` y `render.yaml`.
- Certificado HTTPS gestionado y activo para el consumo seguro desde la aplicación móvil.

### Negativas y Mitigaciones
- **Suspensión por inactividad (Spin-down):** Tras 15 minutos sin recibir tráfico HTTP, Render pone la instancia gratuita en reposo. La siguiente petición experimenta un retraso de inicio en frío (*cold start*) de 30 a 50 segundos mientras se levanta el contenedor.
  - *Mitigación:* Se documenta este comportamiento en la arquitectura (arc42 sección 7 y ADR); los evaluadores y usuarios conocen que el primer contacto puede tardar unos segundos, reanudando la latencia normal en las solicitudes subsecuentes.
- **Límite de horas de cómputo:** Render Free asigna 750 horas de cómputo al mes por cuenta. Dado que un mes de 31 días tiene 744 horas, una única instancia puede operar continuamente sin agotar la cuota.

## Trazabilidad

| Aspecto / Requisito | Elementos C4 relevantes | Artefactos / Documentación | Pruebas / Evidencia |
|---|---|---|---|
| Hosting backend sin costo | [API en Render](../arc42/07_vista_de_despliegue.md) | `backend/Dockerfile`, `render.yaml` | [Verificación externa vía curl](../evidencia/despliegue-externo.md) |
| Automatización de infraestructura | Servidor de aplicación | `render.yaml` | URL pública activa (`https://as-202620-routb.onrender.com/health`) |
| Restricción de presupuesto ($0 USD) | Todo el entorno de cómputo | [Restricciones arc42](../arc42/02_restricciones_de_arquitectura.md#25-restricciones-comerciales-y-de-alcance) | [Costo mensual](../evidencia/costo_mensual.md) |
| Decisión complementaria de BD | Servidor de datos | [ADR 0006 - Base de datos Supabase](0006-base-de-datos-supabase.md) | Conexión remota PostgreSQL |
