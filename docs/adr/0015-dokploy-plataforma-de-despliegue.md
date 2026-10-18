# 0015 - Dokploy como plataforma de despliegue del backend

## Estado

Aceptado. Reemplaza a [ADR 0005 - Render como plataforma de despliegue](0005-render-plataforma-de-despliegue.md).

## Contexto

El backend de ROUTB se desplegó originalmente en Render (Web Service - Free Tier) bajo el subdominio `as-202620-routb.onrender.com`. Esa decisión satisfacía las restricciones vigentes en su momento (ADR 0005): costo $0 y sin tarjeta de crédito.

Tras un corte de operación en producción, registrado en [SEMANA10.md](../evidencia/SEMANA10.md), se evaluaron las siguientes limitaciones de ese modelo:

1. **Arranques en frío.** El plan gratuito suspende la instancia tras 15 minutos sin tráfico y la primera petición posterior tarda entre 30 a 50 segundos. Ese tiempo ocurre antes de que el registro de actividad empiece a medir, de modo que la métrica de percentil 95 no lo captura; sí afecta la experiencia de quien usa la aplicación y fue el motivo declarado de la migración.
2. **Dependencia del proveedor sin control.** No es posible ajustar el dimensionamiento de memoria, los límites del proceso ni el ciclo de vida del contenedor.
3. **Identificador de URL que no pertenece al proyecto.** El subdominio de Render no es del proyecto, lo que dificulta presentar la plataforma y complica apuntar clientes a un dominio propio.
4. **Consistencia entre la base de datos y la aplicación.** El proyecto ya administra un recurso externo (Supabase); el servidor no debía quedar atado a un proveedor con plan gratuito.

La migración se realiza **sin levantar la restricción RC-04** (costo recurrente $0.00 USD y cero tarjetas de crédito, ver [arc42/02](../arc42/02_restricciones_de_arquitectura.md)): el uso de Dokploy en este proyecto no genera costo, y el servidor donde se ejecuta tampoco genera facturación para el equipo. La base de datos permanece en el plan gratuito de Supabase (ADR 0006 no cambia).

## Decisión

Se adopta **Dokploy** como plataforma de cómputo y despliegue del backend, sobre un servidor propio y con el dominio `routb.iscoutb.dev`.

1. **Contenedor OCI sin cambios.** `backend/Dockerfile` se conserva tal cual: expone el puerto 8000, escucha en `0.0.0.0`, respeta la variable `PORT` y ejecuta el proceso como el usuario sin privilegios `appuser`. La imagen que Render construía es la misma que Dokploy construye.
2. **Dominio y TLS.** El dominio `routb.iscoutb.dev` se declara en el panel de Dokploy y el certificado TLS se emite una vez que el registro DNS resuelve hacia la IP del servidor.
3. **Configuración en el panel, con manifiesto de referencia en el repositorio.** El repositorio conserva `compose.lab.yaml`, que declara el servicio, el contexto de compilación y la lista de variables de entorno. Ese archivo documenta el contenedor; los valores reales de los secretos, el dominio y la política de despliegue se administran desde el panel de Dokploy. Se elimina `render.yaml`, que describía la configuración de la plataforma anterior.
4. **Despliegue automatizado.** El servicio se conecta al repositorio de GitHub sobre la rama `Changes`. El panel de Dokploy debe quedar configurado para desplegar solo cuando el flujo de CI termine en verde; queda pendiente verificar y documentar esa condición.
5. **Base de datos sin cambios.** `DATABASE_URL` sigue apuntando a Supabase (ADR 0006). No hay migración de datos: el despliegue en Dokploy reutiliza la base existente.

## Alternativas consideradas

### Mantener Render

- **Ventajas:** cero cambios operativos, despliegue ya automatizado, costo $0.
- **Motivo de descarte:** el arranque en frío de 30 a 50 segundos afecta directamente la experiencia del usuario. La métrica de percentil 95 no lo captura (ver punto 1), pero era el comportamiento documentado de la plataforma y el motivo declarado de la migración. Además no resuelve la necesidad de un dominio propio.

### Dokploy autoalojado (alternativa elegida)

- **Ventajas:** elimina el arranque en frío, permite dominio propio y TLS automático, da control del dimensionamiento y unifica la operación del servidor.
- **Desventajas:** el equipo pasa a ser responsable de la disponibilidad del servidor (parches, reinicios, monitorización).
- **Costo:** el uso de Dokploy en este proyecto no genera costo. Ver [docs/evidencia/costo_mensual.md](../evidencia/costo_mensual.md).

### Kubernetes (k3s) desnudo, sin Dokploy

- **Ventajas:** control total de la plataforma.
- **Motivo de descarte:** la operación de clústeres queda fuera del alcance del proyecto y el equipo no administra esa plataforma. Dokploy aporta panel, certificado TLS, despliegue continuo y manejo de secretos sin exigir ese conocimiento.

### Contenedores directamente sobre Docker Compose, sin proxy

- **Ventajas:** menos componentes.
- **Motivo de descarte:** obliga a gestionar a mano la terminación TLS, la renovación de certificados y el reinicio del servicio. Justifica usar la capa de Dokploy.

## Consecuencias

### Positivas

- **Sin arranque en frío.** El mecanismo que lo causaba en Render (suspensión de la instancia tras 15 minutos sin tráfico) no existe en Dokploy: el contenedor corre de forma continua y la plataforma no lo suspende por inactividad. En todas las mediciones externas la latencia estuvo estable alrededor de 680 ms y nunca se observó un arranque en frío ([evidencia](../evidencia/despliegue-dokploy.md)).
- **Dominio propio** (`routb.iscoutb.dev`) bajo control del proyecto.
- **Sin cambios en el contenedor ni en la base de datos**: la migración no alteró el código de la aplicación ni los datos.
- **Eliminación de la superficie expuesta duplicada**: queda pendiente documentar en qué momento se detuvo el servicio de Render. Mientras siga activo, la misma API responde en dos dominios.

### Negativas y mitigaciones

- **Disponibilidad ahora es responsabilidad del equipo.** Un servidor caído no se reinicia solo como lo hacía la plataforma alojada.
  - *Mitigación:* el servicio queda bajo una plataforma con verificación de salud y despliegue automatizado desde el repositorio.
- **La restricción RC-04 se mantiene cumplida.** El uso de Dokploy en este proyecto no genera costo, de modo que la decisión no obliga a renunciar al requisito de costo cero ni a asociar tarjetas de crédito.
  - *Mitigación:* la estimación de costos se actualizó para reflejar la nueva arquitectura sin alterar el total. Ver [docs/evidencia/costo_mensual.md](../evidencia/costo_mensual.md).
- **Se pierde el despliegue declarativo de extremo a extremo.** `render.yaml` se elimina y la configuración efectiva de Dokploy (dominio, política de despliegue y secretos) no queda versionada. `compose.lab.yaml` documenta el contenedor y las variables, pero no la aplica.
  - *Mitigación:* se conserva `compose.lab.yaml` como manifiesto de referencia del contenedor y sus variables. El enlace a `render.yaml` que queda en [despliegue-externo.md](../evidencia/despliegue-externo.md) permanece roto por la eliminación de ese archivo.
- **Un solo servidor, sin réplicas.** No hay tolerancia a fallos de hardware.
  - *Mitigación:* se acepta para el alcance académico. Ante una caída, el restablecimiento es manual. Los datos permanecen en Supabase, con sus respaldos.

## Trazabilidad

| Aspecto / Requisito | Elementos C4 relevantes | Artefactos / Documentación | Pruebas / evidencia existente |
|---|---|---|---|
| Hosting del backend accesible por HTTPS | [Servidor de ROUTB](../arc42/07_vista_de_despliegue.md) | `backend/Dockerfile`, `compose.lab.yaml` | [Verificación externa en Dokploy](../evidencia/despliegue-dokploy.md) |
| Automatización de infraestructura | Servidor de aplicación | `compose.lab.yaml`; panel de Dokploy | [Verificación externa en Dokploy](../evidencia/despliegue-dokploy.md) (endpoint `/health` activo) |
| Restricción de presupuesto | Capa de cómputo | [Restricciones arc42](../arc42/02_restricciones_de_arquitectura.md) | [Costo mensual](../evidencia/costo_mensual.md) |
| Decisión complementaria de base de datos | Servidor de datos | [ADR 0006 - Supabase](0006-base-de-datos-supabase.md) | Conexión remota PostgreSQL sin cambios |
