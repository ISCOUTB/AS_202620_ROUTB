# Estimación de Costo Mensual y Punto de Ruptura de la Capa Gratuita ($0 USD)

## 1. Supuestos de Volumen y Carga (Escenarios de Calidad)

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

## 2. Desglose de Costos por Componente de Infraestructura

| Componente | Proveedor | Recurso / Plan | Capacidad Incluida | Consumo Estimado ROUTB | Costo Mensual ($ USD) |
|---|---|---|---|---|---|
| **Cómputo Backend API** | **Render** | Web Service (Free Tier) | 750 horas/mes de instancia, 512 MB RAM, 0.1 CPU compartida | 720 horas/mes (1 instancia continua), ~150 MB RAM usada | **$0.00** |
| **Base de Datos Relacional** | **Supabase** | PostgreSQL Cloud (Free Tier) | 500 MB almacenamiento, 2 proyectos activos, conexión PgBouncer | ~50 MB almacenamiento semestral, 20 conexiones simultáneas | **$0.00** |
| **Transferencia y Egress** | **Render & Supabase** | Egress incluido | 100 GB/mes (Render) / 5 GB/mes (Supabase) | ~0.6 GB/mes | **$0.00** |
| **Certificados TLS / HTTPS** | **Render** | Let's Encrypt Gestionado | Renovación automática ilimitada | 1 dominio `.onrender.com` | **$0.00** |
| **Pipeline de CI/CD** | **GitHub Actions** | Repositorio público / Free Tier | 2.000 minutos/mes (o ilimitado en repositorios públicos) | ~150 minutos/mes (~50 ejecuciones de 3 min) | **$0.00** |
| **Registro de Contenedores** | **Render Build Cache** | Docker Builder interno | Builds estándar basados en Git | ~15 builds/mes | **$0.00** |
| **Costo Total Estimado** | — | — | — | — | **$0.00 USD/mes** |

---

## 3. Análisis de Punto de Ruptura de la Capa Gratuita

A continuación se determina con precisión el umbral a partir del cual cada servicio superaría los límites gratuitos y qué impacto tendría:

### 3.1 Cómputo del Backend (Render Free Tier)
* **Límite gratuito:** 750 horas de cómputo por mes por cuenta y 512 MB de memoria RAM.
* **Punto de ruptura:**
  1. *Horas de uso:* Si el equipo añade un segundo servicio web en la misma cuenta gratuita (por ejemplo, frontend web independiente o worker en segundo plano), las 750 horas se repartirían, agotándose a mitad de mes (día 15).
  2. *Memoria RAM:* Si la concurrencia supera los **180-200 usuarios concurrentes reales** o si se realizan cargas en memoria de mapas/grafos que superen los **512 MB**, el kernel de Render emitirá un evento OOM (*Out Of Memory Killer*) y reiniciará el contenedor.
* **Siguiente escalón (Plan de contingencia):**
  - Pasar al plan *Starter Web Service* en Render ($7 USD/mes por instancia, con 512 MB RAM fija sin spin-down) o *Standard* ($25 USD/mes, 2 GB RAM).

### 3.2 Base de Datos (Supabase Free Tier)
* **Límite gratuito:** 500 MB de almacenamiento en disco, 50.000 usuarios activos mensuales, 5 GB de ancho de banda y pausa del proyecto tras 7 días sin peticiones.
* **Punto de ruptura:**
  1. *Almacenamiento:* Con un volumen de 500 estudiantes y 600 recorridos/mes, se requerirían más de **5 años continuos de histórico sin depuración** para aproximarse a los 500 MB.
  2. *Inactividad:* Si durante vacaciones académicas pasan más de 7 días continuos sin que nadie ingrese a la app, Supabase pausa la base de datos (requiere un clic manual en el dashboard para reactivarla sin pérdida de datos).
* **Siguiente escalón (Plan de contingencia):**
  - Supabase *Pro Plan* ($25 USD/mes con 8 GB de almacenamiento y sin pausa por inactividad).

### 3.3 Ancho de Banda y Red
* **Límite gratuito:** 100 GB/mes en Render.
* **Punto de ruptura:** Con el tráfico actual de ~0.6 GB/mes, se necesitaría multiplicar el tráfico por más de **150 veces** (> 25.000.000 de solicitudes/mes) para exceder el ancho de banda gratuito.

---

## 4. Conclusión de Viabilidad

El dimensionamiento de ROUTB para el alcance académico demuestra que:
1. La plataforma opera holgadamente dentro de los márgenes de los planes gratuitos (**menos del 10 % del cupo de almacenamiento de Supabase** y **menos del 1 % del ancho de banda de Render**).
2. Se cumple de manera estricta la restricción **RC-04 (Costo $0 USD y Cero Tarjetas de Crédito)**.
3. El único riesgo operativo asociado a la capa gratuita es el retardo de arranque en frío (*cold start* de 30-50 segundos en Render tras 15 minutos de inactividad), el cual es asumible y está contemplado en el ADR 0005.
