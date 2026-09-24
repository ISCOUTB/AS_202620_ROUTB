# 0005 - Elección de plataforma de despliegue e infraestructura en la nube ($0 Costos)

## Estado

Aceptado

## Contexto

ROUTB requiere una plataforma de despliegue para el backend contenerizado (FastAPI) y la base de datos relacional (PostgreSQL), con el objetivo de permitir el acceso público vía HTTPS desde fuera de la red de la universidad y permitir la verificación de endpoints de salud y negocio.

El proyecto se rige por restricciones académicas estrictas:
- **Presupuesto cero ($0 USD):** No existe partida presupuestaria para infraestructura.
- **Sin tarjeta de crédito:** Ningún integrante del equipo dispone de tarjeta de crédito para asociar a proveedores en la nube, ni se acepta incurrir en riesgos de cobros automáticos por descuidos de uso.
- **Volumen objetivo:** Soportar hasta 100 usuarios concurrentes en franjas de alta demanda (definido en `docs/arc42/10_requisitos_de_calidad.md`), con disponibilidad objetivo del 99 %.

Se requiere seleccionar una combinación de hosting y base de datos que garantice operación real, reproducible y declarada como código (IaC), respetando íntegramente la restricción de costo nulo.

## Decisión

Se adopta la combinación de **Render (Free Web Service)** para el cómputo del backend y **Supabase (Free Tier)** para la base de datos PostgreSQL administrada:

1. **Cómputo Backend:** Web Service en **Render** desplegado a partir del `backend/Dockerfile` versionado en el repositorio y orquestado mediante el manifiesto `render.yaml`.
2. **Base de Datos:** Instancia gestionada de PostgreSQL 15 en **Supabase**, utilizando conexión segura y pool de conexiones (PgBouncer) para optimizar el uso de conexiones concurrentes.
3. **Automatización:** Manifiesto de plataforma (`render.yaml`) versionado y sincronización continua con la rama principal de GitHub.

Criterios determinantes:
- **Ausencia total de medios de pago:** Render y Supabase permiten registro y despliegue funcional en sus capas gratuitas sin exigir tarjeta de crédito.
- **Soporte de Docker nativo:** Render construye y ejecuta directamente el `Dockerfile` del backend sin configuraciones propietarias.
- **Certificados SSL automáticos:** Ambas herramientas proporcionan terminación TLS/HTTPS pública de forma gratuita.

## Alternativas consideradas

### Fly.io
- **Ventajas:** Excelente latencia y manejo de contenedores ligeros Firecracker.
- **Motivo de descarte:** Exige una tarjeta de crédito válida para verificar la cuenta antes de permitir crear o desplegar aplicaciones, violando directamente la restricción fundamental de no poseer tarjeta.

### Railway
- **Ventajas:** Despliegue intuitivo y soporte nativo de Docker.
- **Motivo de descarte:** Su modelo de capa gratuita es temporal (crédito único de $5 USD o límite de 30 días de prueba). Al agotarse el crédito o el mes, los servicios se suspenden a menos que se ingrese un método de pago. No es viable para la duración del semestre.

### AWS / Google Cloud Platform / Microsoft Azure
- **Ventajas:** Ecosistemas líderes y altamente escalables.
- **Motivo de descarte:** Exigen tarjeta de crédito para la activación de la cuenta. Además, presentan una alta complejidad operativa y riesgo de facturación imprevista al expirar el periodo promocional o por tráfico entrante.

## Consecuencias

### Positivas
- Cumplimiento estricto del presupuesto: costo mensual recurrente de **$0.00 USD**.
- Cumplimiento de la restricción de medios de pago: cero tarjetas de crédito requeridas.
- Infraestructura como código: la definición del servicio queda formalizada en `backend/Dockerfile` y `render.yaml`.
- Base de datos relacional robusta en la nube con copias de seguridad automáticas provistas por Supabase.

### Negativas y Mitigaciones
- **Suspensión por inactividad (Spin-down):** En la capa gratuita de Render, si el servicio no recibe tráfico durante 15 minutos, la instancia entra en reposo. La siguiente petición experimenta un retraso de inicio en frío (*cold start*) de 30 a 50 segundos.
  - *Mitigación:* Se documenta este comportamiento en la vista de arquitectura y se asume aceptable para el contexto académico; las pruebas del evaluador o del equipo contemplan este tiempo en el primer contacto.
- **Límites de recursos:** Render Free asigna 512 MB de RAM y 0.1 CPU compartida, con un tope de 750 horas de cómputo por mes (suficiente para mantener un servicio activo de forma continua durante un mes de 31 días = 744 horas).

## Trazabilidad

| Aspecto / Requisito | Elementos C4 relevantes | Artefactos / Documentación | Pruebas / Evidencia |
|---|---|---|---|
| Hosting y despliegue sin costo | Contenedor Backend API | `backend/Dockerfile`, `render.yaml` | URL pública activa y respuesta HTTP 200 en `/health` |
| Persistencia en la nube | Base de datos PostgreSQL | Supabase Free Tier, `backend/alembic/` | Conexión y migración en base de datos remota |
| Restricción presupuestaria ($0) | Infraestructura global | `docs/arc42/02_restricciones_de_arquitectura.md`, `docs/evidencia/costo_mensual.md` | Verificación de facturación en $0 USD |
