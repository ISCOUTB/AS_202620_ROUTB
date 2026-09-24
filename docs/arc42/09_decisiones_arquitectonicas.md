# 9. Decisiones arquitectónicas

Las decisiones arquitectónicas que impactan significativamente la estructura, la integración, el mantenimiento, la escalabilidad y el despliegue del sistema ROUTB se formalizan en los siguientes Registros de Decisiones Arquitectónicas (ADR):

| ADR | Estado | Decisión |
|---|---|---|
| [ADR 0001](../adr/0001-usar-monolito-modular.md) | Aceptado | Adoptar un monolito modular como estilo arquitectónico para el backend de ROUTB. |
| [ADR 0002](../adr/0002-usar-arquitectura-interna-por-capas.md) | Aceptado | Usar una arquitectura interna por capas para estructurar la lógica dentro de cada módulo. |
| [ADR 0003](../adr/0003-control-atomico-de-cupos.md) | Aceptado | Usar una actualización atómica condicionada en SQL para evitar la sobreventa de cupos. |
| [ADR 0004](../adr/0004-integracion-sincrona-rest.md) | Aceptado | Usar integración síncrona mediante API REST sobre HTTPS para la comunicación de clientes y servicios. |
| [ADR 0005](../adr/0005-plataforma-de-despliegue.md) | Aceptado | Adoptar Render (Free Web Service) como plataforma de cómputo y despliegue del backend contenerizado. |
| [ADR 0006](../adr/0006-base-de-datos-supabase.md) | Aceptado | Adoptar Supabase (Free Tier) como plataforma de base de datos relacional PostgreSQL administrada. |

---
