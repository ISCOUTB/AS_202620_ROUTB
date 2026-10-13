# Estimación de costo mensual y puntos de ruptura por capacidad

## 1. Supuestos de volumen y carga (Escenarios de Calidad)

De acuerdo con lo definido en el Árbol de Utilidad y Escenarios de Calidad de ROUTB (`docs/arc42/10_requisitos_de_calidad.md`):

- **Concurrencia objetivo:** Hasta 100 usuarios concurrentes en periodos pico (llegada matutina 06:30–08:30 y salida vespertina 16:30–18:30 a la Universidad Tecnológica de Bolívar).
- **Población activa mensual estimada:** ~500 estudiantes activos/mes.
- **Viajes publicados:** ~20 recorridos diarios = 600 recorridos/mes.
- **Solicitudes de reserva:** ~4 solicitudes por recorrido = 2.400 reservas/mes.
- **Peticiones HTTP mensuales promedio:**
  - Consultas de recorridos y health checks: ~10 solicitudes por usuario por sesión activa.
  - Total estimado: 500 usuarios × 20 días lectivos × 15 solicitudes/día ≈ **150.000 solicitudes HTTP/mes**.
  - Tamaño promedio por payload JSON: ~2 KB por petición/respuesta.
  - Transferencia de red mensual estimada (Bandwidth): 150.000 × 4 KB ≈ **600 MB/mes (~0.6 GB/mes)**.
- **Almacenamiento en Base de Datos:**
  - Esquema inicial (usuarios, viajes, solicitudes): ~50 KB por cada 100 registros.
  - Almacenamiento estimado para un semestre completo de operación: **< 50 MB** (incluyendo índices y tablas de auditoría).

---

## 2. Desglose de costos por componente de infraestructura

| Componente | Proveedor | Recurso / Plan | Capacidad Incluida | Consumo Estimado ROUTB | Costo Mensual ($ USD) |
|---|---|---|---|---|---|
| **Cómputo Backend API** | **Servidor propio / Dokploy** | Dokploy | Sin costo para el proyecto; capacidad limitada por el servidor donde se ejecuta | 1 instancia continua; consumo de RAM de la API sin medir | **$0.00** |
| **Base de Datos Relacional** | **Supabase** | PostgreSQL Cloud (Free Tier) | 500 MB almacenamiento, 2 proyectos activos, conexión PgBouncer | ~50 MB almacenamiento semestral, 20 conexiones simultáneas | **$0.00** |
| **Transferencia y Egress** | **Servidor propio & Supabase** | Incluido en el servidor | 5 GB/mes (Supabase) | ~0.6 GB/mes | **$0.00** |
| **Certificados TLS / HTTPS** | **Let's Encrypt** (gestionado por Dokploy) | Sin costo | Renovación automática ilimitada | 1 dominio `routb.iscoutb.dev` | **$0.00** |
| **Pipeline de CI/CD** | **GitHub Actions** | Repositorio público / Free Tier | 2.000 minutos/mes (o ilimitado en repositorios públicos) | ~150 minutos/mes (~50 ejecuciones de 3 min) | **$0.00** |
| **Gestión de plataforma** | **Dokploy** | Autoalojado en el mismo servidor | — | Alojado junto al backend, sin costo adicional | **$0.00** |
| **Costo Total Estimado** | — | — | — | — | **$0.00 USD/mes** |

---

## 3. Análisis de punto de ruptura de la capa gratuita

A continuación se determina con precisión el umbral a partir del cual cada servicio superaría los límites gratuitos y qué impacto tendría:

### 3.1 Cómputo del Backend (servidor propio con Dokploy)
* **Límite:** la capacidad del servidor propio donde corre Dokploy. Ya no aplican el techo de 750 horas ni el de 512 MB que imponía el plan gratuito de Render.
* **Punto de ruptura:**
  1. *Memoria RAM:* si la carga supera la memoria disponible, el proceso es descartado por el sistema y el contenedor se reinicia. El umbral concreto depende de la RAM del servidor y **no está medido**.
* **Siguiente escalón (Plan de contingencia):**
  - Ampliar el servidor (más RAM y CPU) o distribuir la carga entre varios servicios.

### 3.2 Base de Datos (Supabase Free Tier)
* **Límite gratuito:** 500 MB de almacenamiento en disco, 50.000 usuarios activos mensuales, 5 GB de ancho de banda y pausa del proyecto tras 7 días sin peticiones.
* **Punto de ruptura:**
  1. *Almacenamiento:* Con un volumen de 500 estudiantes y 600 recorridos/mes, se requerirían más de **5 años continuos de histórico sin depuración** para aproximarse a los 500 MB.
  2. *Inactividad:* Si durante vacaciones académicas pasan más de 7 días continuos sin que nadie ingrese a la app, Supabase pausa la base de datos (requiere un clic manual en el dashboard para reactivarla sin pérdida de datos).
* **Siguiente escalón (Plan de contingencia):**
  - Supabase *Pro Plan* ($25 USD/mes con 8 GB de almacenamiento y sin pausa por inactividad).

### 3.3 Ancho de banda y red
* **Límite:** la capacidad de red del servidor propio, más los 5 GB/mes incluidos en Supabase.
* **Punto de ruptura:** Con el tráfico actual de ~0.6 GB/mes, el consumo es marginal para cualquier servidor de uso académico.

---

## 4. Conclusión de viabilidad

El dimensionamiento de ROUTB para el alcance académico demuestra que:
1. La base de datos opera holgadamente dentro de los márgenes del plan gratuito de Supabase (**menos del 10 % del cupo de almacenamiento**), y el consumo de cómputo del backend es marginal.
2. **Se mantiene la restricción RC-04 (Costo $0 USD y Cero Tarjetas de Crédito)**: el uso de Dokploy en este proyecto no genera costo, y el servidor donde se ejecuta tampoco genera facturación para el equipo. El costo total sigue siendo **$0.00 USD/mes**.
3. El arranque en frío (*cold start* de 30-50 segundos tras 15 minutos sin tráfico) **no aplica en Dokploy**: la plataforma no suspende el contenedor por inactividad y el servicio corre de forma continua, por lo que ese mecanismo desaparece. En las mediciones externas la latencia estuvo estable alrededor de 680 ms. Ver [ADR 0015](../adr/0015-dokploy-plataforma-de-despliegue.md) y [verificación de despliegue](despliegue-dokploy.md).
4. El riesgo operativo cambió de naturaleza: ya no está la plataforma que duerme la instancia, sino que el servidor es responsabilidad del equipo. No hay réplicas, de modo que una caída del servidor sí representa indisponibilidad hasta que alguien intervenga.
