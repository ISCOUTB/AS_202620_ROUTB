# 0006 - Elección de plataforma para la base de datos relacional administrada (Supabase)

## Estado

Aceptado

## Contexto

ROUTB requiere una plataforma de persistencia de datos relacional para gestionar entidades con alta necesidad de integridad transaccional (usuarios, viajes, solicitudes de reserva y disponibilidad de cupos).

En particular, el sistema implementa un control de concurrencia atómico para evitar la sobreventa de cupos ([ADR 0003](0003-control-atomico-de-cupos.md)), el cual se fundamenta en sentencias SQL atómicas con bloqueos a nivel de fila y aislamiento ACID en PostgreSQL.

Asimismo, el proyecto se rige por las siguientes restricciones:
- **Presupuesto cero ($0.00 USD):** No se dispone de fondos económicos para adquirir bases de datos dedicadas.
- **Sin tarjeta de crédito:** El proveedor debe permitir crear, mantener y conectar la base de datos sin requerir ninguna tarjeta bancaria ni periodo de prueba que caduque a mitad de semestre.
- **Conectividad remota y segura:** Debe permitir conexiones remotas cifradas (SSL/TLS) tanto desde el backend alojado en Render ([ADR 0005](0005-render-plataforma-de-despliegue.md)) como desde los entornos de desarrollo local y de integración continua.

## Decisión

Se adopta **Supabase (Free Tier)** como plataforma de base de datos relacional PostgreSQL 15 administrada en la nube:

1. **Motor PostgreSQL nativo:** Permite ejecutar directamente el esquema relacional y las migraciones de Alembic (`backend/migrations/`) utilizando tipos de datos nativos, claves foráneas, índices y transacciones concurrentes.
2. **Conexión mediante PgBouncer:** Supabase incluye un pool de conexiones integrado (PgBouncer en el puerto 6543 en modo transacción), optimizando el uso de conexiones concurrentes frente al límite de recursos de la capa gratuita.
3. **Ausencia total de medios de pago:** Permite el aprovisionamiento de una instancia funcional sin solicitar tarjeta de crédito.

## Alternativas consideradas

### Firebase Firestore / MongoDB Atlas (Bases de datos NoSQL)
- **Ventajas:** Facilidad de integración y esquemas flexibles.
- **Motivo de descarte:** El modelo de negocio de ROUTB y la reserva de cupos descrita en el ADR 0003 dependen de transacciones relacionales ACID estrictas (`UPDATE trips SET available_seats = available_seats - 1 WHERE id = ... AND available_seats > 0`). Migrar a NoSQL requeriría reescribir toda la capa de persistencia (SQLAlchemy/Alembic) y aumentaría la complejidad para garantizar la no sobreventa en escenarios concurrentes sin soporte relacional nativo.

### Base de datos PostgreSQL en Render (Render Free PostgreSQL)
- **Ventajas:** Mismo proveedor que el servicio de cómputo del backend.
- **Motivo de descarte:** En la capa gratuita de Render, las instancias de PostgreSQL tienen una expiración obligatoria de 30 días naturales. Al cumplirse ese plazo, la base de datos es eliminada automáticamente y los datos se pierden a menos que se contrate un plan pago de $7 USD/mes. Esta limitación imposibilita su uso durante el semestre académico.

### PostgreSQL autogestionado en máquina virtual (VPS / AWS EC2 / Oracle Cloud Free Tier)
- **Ventajas:** Control total del sistema operativo y configuración del motor.
- **Motivo de descarte:** Los proveedores de VPS con capas gratuitas (como Oracle Cloud o AWS) exigen tarjeta de crédito para la validación de identidad. Además, administrar una máquina virtual propia introduce una alta sobrecarga operativa: configuración manual de cortafuegos, parches de seguridad del sistema operativo, gestión de certificados SSL y configuración manual de copias de seguridad.

### ElephantSQL
- **Ventajas:** Históricamente ofrecía instancias PostgreSQL ligeras gratuitas.
- **Motivo de descarte:** El servicio ElephantSQL anunció oficialmente su cierre y discontinuación definitiva, dejando de aceptar nuevas bases de datos y apagando los clusters existentes en 2025.

## Consecuencias

### Positivas
- Disponibilidad permanente de una base de datos PostgreSQL 15 completa sin costo (**$0.00 USD/mes**).
- No requiere tarjeta de crédito ni medios de pago.
- Capacidad holgada para las necesidades del proyecto: 500 MB de almacenamiento (la estimación semestral de ROUTB es de < 50 MB; ver `docs/evidencia/costo_mensual.md`).
- Copias de seguridad automáticas y consola administrativa web para inspección y consultas SQL.
- Integración transparente con SQLAlchemy, Alembic y el backend en Render vía `DATABASE_URL` con SSL requerido.

### Negativas y Mitigaciones
- **Pausa por inactividad prolongada:** Supabase suspende el proyecto si pasan 7 días continuos sin ninguna solicitud entrante.
  - *Mitigación:* Durante el periodo de clases, la actividad continua de desarrollo y las pruebas académicas impiden la inactividad; en caso de suspensión tras un periodo vacacional, el proyecto se reactiva con un solo clic en el panel de control de Supabase sin pérdida de información ni alteración de esquemas.

## Trazabilidad

| Aspecto / Requisito | Elementos C4 relevantes | Artefactos / Documentación | Pruebas / Evidencia |
|---|---|---|---|
| Persistencia relacional en la nube | [Base de datos en Supabase](../arc42/07_vista_de_despliegue.md) | `backend/migrations/`, `backend/app/shared/database.py` | Conexión remota verificada |
| Control atómico de cupos | Servidor de base de datos | [ADR 0003 - Control atómico](0003-control-atomico-de-cupos.md) | `backend/tests/test_cupos.py` |
| Restricción de presupuesto ($0 USD) | Infraestructura de datos | [Restricciones arc42](../arc42/02_restricciones_de_arquitectura.md) | [Costo mensual](../evidencia/costo_mensual.md) |
| Plataforma de cómputo asociada | Servidor de aplicación | [ADR 0005 - Render](0005-render-plataforma-de-despliegue.md) | Endpoint `/health` |
