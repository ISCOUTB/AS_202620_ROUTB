# Informe Técnico: Alternativas de Despliegue, Modelo de Costos y Decisión Arquitectónica (ADR 0005)

| | |
|---|---|
| **Proyecto** | ROUTB — Plataforma de movilidad colaborativa para estudiantes de la Universidad Tecnológica de Bolívar (UTB) |
| **Pieza evaluada** | **API REST (Backend FastAPI)**, endpoint representativo `GET /trips/` |
| **Condición operativa asignada** | **Costo = $0 USD/mes**, sin tarjeta de crédito (restricción RC-04) |
| **Alternativas comparadas** | A. Render (Web Service, Free) · B. Railway (Web Service) |
| **Base de datos** | PostgreSQL en Supabase Free Tier |
| **URLs** | [Render](https://as-202620-routb.onrender.com) y [Railway](https://as202620routb-production.up.railway.app) |

## Resumen ejecutivo

| | |
|---|---|
| **Decisión** | Desplegar la API en **Render (Free Tier)** |
| **Motivo** | Es la única alternativa que cumple **$0/mes sin tarjeta**. Railway es más rápido, pero requiere plan de pago y tarjeta para operar de forma sostenida |
| **Rendimiento (p95 en caliente)** | Render **0,52 – 0,80 s** · Railway 0,34 – 0,69 s · Umbral **3,99 s** |
| **Costo estimado** | Render **$0,00/mes** (480 de 750 h gratuitas) · Railway **$5,00/mes** mínimo |
| **Riesgo aceptado** | Arranque en frío de Render (~65 s) ante uso fuera de la ventana 05:00–21:00 |

---

## 1. Definición de la pieza y supuestos

### 1.1 Pieza evaluada

La evaluación se limita a la **API REST del backend** de ROUTB. El endpoint representativo, sobre el que se mide el escenario de calidad, es `GET /trips/` (consulta de trayectos y cupos disponibles). El resto del sistema (cliente Flutter, base de datos) queda fuera del alcance.

- **Rol:** servidor de aplicación del monolito modular; expone la API sobre HTTPS al cliente móvil.
- **Stack:** Python 3.11+, FastAPI, Uvicorn, SQLAlchemy 2.0, Alembic, JWT.
- **Naturaleza:** sin estado (*stateless*). Ninguna de las dos alternativas es una función serverless (FaaS): ambas ejecutan la API como un contenedor.

### 1.2 Supuestos de carga


| Supuesto | Valor |
|---|---|
| Concurrencia objetivo | Hasta **100 usuarios concurrentes** en picos |
| Franjas pico | 06:30–08:30 y 16:30–18:30 |
| Población activa mensual | ~**500 estudiantes** |
| Peticiones HTTP | 500 usuarios × 20 días lectivos × 15 solicitudes/día = **150.000/mes** |
| Payload por intercambio | ~2 KB petición + ~2 KB respuesta = **~4 KB** |
| Egress mensual | 150.000 × 4 KB ≈ **0,6 GB/mes** |
| Recursos del contenedor | 1 instancia, ~150 MB RAM en uso, CPU compartida |
| Almacenamiento en BD | < 50 MB por semestre |
| **Ventana de uso real** | **05:00 – 21:00 (16 h/día)**. Fuera de ella no hay demanda modelada |

### 1.3 Escenario de calidad de referencia

| Atributo | Rendimiento / latencia en condiciones normales |
|---|---|
| Estímulo | El usuario consulta los viajes disponibles (`GET /trips/`) |
| Umbral | **p95 ≤ 3,99 s** |
| Disponibilidad | ≥ **99 %** en franjas pico |

---

## 2. Alternativas evaluadas

### 2.1 Alternativa A: Render (Web Service, Free Tier)

- **Costo:** $0. No requiere tarjeta. Cupo de **750 h/mes** de instancia.
- **Suspensión (*spin-down*):** tras 15 min sin tráfico HTTP el contenedor se apaga; al llegar una petición se reactiva (**~65 s** medidos, ver 4.2).
- **Estrategia keep-alive a costo $0:** una petición al endpoint de salud cada **14 min**, solo entre **05:00 y 21:00**, ejecutado con GitHub Actions (cron) o UptimeRobot. Con esto el servicio permanece activo durante toda la ventana de uso.
- **Consumo de cómputo:** 16 h/día × 30 días = **480 h/mes** de 750 h (64 %), con **270 h de margen**.

### 2.2 Alternativa B: Railway (Web Service)

- **Costo:** planes de pago por uso. El **Hobby** es un **mínimo de $5/mes** que se convierte en crédito de uso (no es una tarifa fija: si el consumo supera $5, se cobra el consumo). Requiere tarjeta de crédito.
- **Plan Free:** existe un plan Free permanente ($1/mes de crédito tras una prueba de 30 días), pero su crédito no alcanza para mantener la API activa todo el mes (ver 5.2).
- **Operación:** el servicio permanece activo sin hibernación, por lo que no tiene arranque en frío relevante (0,479 s medidos).

### 2.3 Cobertura del keep-alive frente al perfil de uso

Como el keep-alive cubre toda la ventana real de uso, el p95 real modelado de Render **coincide con su p95 en caliente**, sin incorporar el arranque en frío al tráfico normal.

- **Riesgo residual (no modelado):** una interacción fuera de horario (p. ej. 2:00 AM) activaría el arranque en frío. Se acepta porque no hay demanda esperada en ese horario. Si el patrón de uso cambia, el keep-alive debe ampliarse.
- **Riesgo de términos de servicio:** el ping periódico es una práctica extendida, pero la capa gratuita está pensada para tráfico intermitente. Por eso la estrategia se limita a la ventana real y se documenta como **decisión consciente, no garantía contractual** del proveedor.

---

## 3. Plan de despliegue reproducible

El despliegue se reproduce siguiendo los pasos de esta sección, con las variables de entorno indicadas y la medición descrita en la sección 4.

### 3.1 Pasos

1. **Crear el servicio** en Render y en Railway a partir del repositorio de GitHub, con despliegue automático al hacer *push*.
2. **Configurar variables de entorno** como secretos del proveedor (ver 3.2).
3. **Activar el keep-alive** en Render (cron de GitHub Actions o UptimeRobot) con la ventana 05:00–21:00.
4. **Verificar** que el endpoint de salud responda HTTP 200 y ejecutar la medición descrita en la sección 4.

### 3.2 Variables de entorno

| Variable | Descripción |
|---|---|
| `DATABASE_URL` | Cadena de conexión a Supabase |
| `JWT_SECRET_KEY` | Clave de firma de tokens |
| `JWT_ALGORITHM` | `HS256` |
| `JWT_EXPIRE_MINUTES` | `60` |

> Los valores reales **no se versionan ni se publican**: se cargan como secretos en el panel del proveedor. Si alguna clave de ejemplo se usó en un despliegue real, debe rotarse.

---

## 4. Metodología y resultados de la medición

### 4.1 Metodología

| Parámetro | Valor |
|---|---|
| Endpoint | `GET /trips/` |
| Peticiones por corrida | 100, secuenciales, desde un único cliente |
| Calentamiento previo | 1 petición al endpoint de salud + 5 s de espera |
| Filtro | Solo respuestas HTTP 200 |
| Cálculo del p95 | Ordenar los tiempos y tomar el elemento en la posición ⌈0,95 × N⌉ |
| Corridas | 2, independientes, en caliente |
| Arranque en frío | 1 medición por entorno tras > 15 min de inactividad, sobre el endpoint de salud |

### 4.2 Resultados

**Corrida 1**

| Métrica | Render | Railway |
|---|---:|---:|
| Mínima | 0,4345 s | 0,2476 s |
| Promedio | 0,4763 s | 0,3005 s |
| **p95** | **0,5161 s** | **0,3400 s** |
| Máxima | 0,6712 s | 0,4217 s |

**Corrida 2**

| Métrica | Render | Railway |
|---|---:|---:|
| Mínima | 0,4313 s | 0,2699 s |
| Promedio | 0,5922 s | 0,3972 s |
| **p95** | **0,8048 s** | **0,6900 s** |
| Máxima | 1,0486 s | 0,9258 s |

**Arranque en frío**

| | Render | Railway |
|---|---:|---:|
| Primera respuesta tras inactividad | **~65,0 s** | 0,4790 s |

### 4.3 Lectura

- El p95 casi se duplicó entre corridas en ambos entornos (probable variabilidad de red o de host compartido, no de código). Aun así, el peor caso (Render, 0,80 s) deja un margen de **~5×** frente al umbral de 3,99 s.
- Railway es más rápido y estable, pero ambos cumplen el escenario de calidad.
- **Limitaciones:** las peticiones son secuenciales desde un solo cliente, por lo que no validan el objetivo de 100 usuarios concurrentes; se recomienda una prueba concurrente (k6 o Locust) como mejora futura. Además, el arranque en frío de Render se midió una sola vez.

### 4.4 Matriz comparativa

| Criterio | A. Render (Free) | B. Railway (Hobby) |
|---|---|---|
| Costo mensual sostenido | **$0,00** | **$5,00** mínimo (ver 5.2) |
| Tarjeta de crédito | **No requiere** | Requiere |
| Horas de cómputo | 480 h de 750 h gratuitas | Facturación por uso (RAM y CPU) |
| p95 en caliente (medido) | 0,52 – 0,80 s | **0,34 – 0,69 s** |
| Arranque en frío (medido) | ~65 s *(no aplica al tráfico modelado)* | **0,479 s** |
| Disponibilidad en picos | ≥ 99 % (vía keep-alive) | ≥ 99,5 % |
| Cumple umbral p95 ≤ 3,99 s | Sí | Sí |
| Reversibilidad | Alta (contenedor portable) | Alta (contenedor portable) |
| Operación por el equipo | Alta (deploy por *push*) | Alta (deploy por *push*) |

---

## 5. Estimación de costo y punto de ruptura de la capa gratuita

Se aplica la misma metodología a ambas alternativas: consumo estimado del supuesto de la sección 1.2 frente a los límites del plan.

### 5.1 Render (Free Tier)

| Componente | Capacidad gratuita | Consumo estimado | Costo |
|---|---|---|---:|
| Cómputo | 750 h/mes, 512 MB RAM | **480 h/mes**, ~150 MB RAM | $0,00 |
| Egress | 100 GB/mes | ~0,6 GB/mes | $0,00 |
| TLS / HTTPS | Certificado gestionado | 1 dominio `.onrender.com` | $0,00 |
| CI/CD y builds | GitHub Actions y builds por Git | ~150 min/mes, ~15 builds | $0,00 |
| **Total** | | | **$0,00** |

**Puntos de ruptura**

| Disparador | Efecto | Escalón siguiente |
|---|---|---|
| **Segundo servicio** en la misma cuenta (+480 h): 960 h > 750 h | Cupo agotado hacia el **día 23**; se suspenden los servicios web | Plan de pago |
| **Cobertura 24/7** (~720 h/mes) por cambio del patrón de uso | Se acerca al tope y contradice el margen de 270 h | *Starter*: **$7/mes** (sin spin-down) |
| **RAM > 512 MB** (cargas en memoria o ~180–200 usuarios concurrentes reales) | El contenedor se reinicia por falta de memoria | *Starter* $7/mes o *Standard* $25/mes (2 GB) |
| **Egress > 100 GB/mes** | Requeriría ~175× el tráfico actual (≈ 26 M de solicitudes/mes) | Plan de pago |

### 5.2 Railway

Tarifas de uso (septiembre de 2026): **RAM $10/GB-mes**, **CPU $20/vCPU-mes**, **egress $0,05/GB**. El plan Hobby tiene un mínimo de $5/mes que se descuenta como crédito de uso; se paga el mayor entre $5 y el consumo.

| Componente | Consumo estimado (servicio activo 24/7) | Costo |
|---|---|---:|
| RAM | 0,15 GB × $10 | $1,50 |
| CPU | ~0,05 vCPU × $20 | $1,00 |
| Egress | 0,6 GB × $0,05 | $0,03 |
| **Consumo de uso** | | **≈ $2,53** |
| **Factura (Hobby)** | mayor entre $5 (mínimo) y el consumo | **$5,00** |

> Railway no hiberna el servicio, por lo que se estima 24/7 (730 h/mes). El consumo de CPU (~0,05 vCPU promedio) es un supuesto: debe verificarse con las métricas reales del despliegue.

**Puntos de ruptura**

| Disparador | Efecto | Escalón siguiente |
|---|---|---|
| **Cualquier operación sostenida** | El mínimo de $5/mes y la tarjeta se exigen desde el primer mes: el **$0 se rompe de inmediato** | — |
| **Plan Free** ($1/mes de crédito) | Cubre solo ~290 h de un servicio de este tamaño (~12 días 24/7); el servicio se detendría | Plan Hobby |
| **RAM > ~0,4 GB** (con ~0,05 vCPU) | El consumo supera los $5 de crédito y se cobra el excedente | Pago por uso adicional |

### 5.3 Conclusión de costos

1. Render opera dentro de la capa gratuita con margen (64 % de las horas, < 1 % del egress) y cumple **RC-04**.
2. Railway tendría un costo mensual bajo (**$5**), pero incumple la restricción de $0 y de no usar tarjeta.
3. El costo de Render está condicionado a mantener **un solo servicio** en la cuenta y **la ventana de 16 h/día**.

---

## 6. Procedimiento de reversión (rollback)

### 6.1 Reversión de una versión defectuosa (mismo proveedor)

1. Identificar el último despliegue estable en el historial del servicio (Render o Railway).
2. Ejecutar *Rollback / Redeploy* a esa versión desde el panel del proveedor.
3. Si el defecto incluye una migración de base de datos, revertirla **antes** de reactivar el tráfico.
4. Verificar que el endpoint de salud responda HTTP 200 y que la prueba de atomicidad de cupos pase.

### 6.2 Reversión de plataforma (Render → Railway)

Aplica si Render deja de responder por más de 2 minutos. Como la API es *stateless*, no hay pérdida de datos de negocio.

1. **Detección:** el monitoreo (UptimeRobot) reporta caída sostenida de Render.
2. **Conmutación:** activar el despliegue de respaldo en Railway (`https://as202620routb-production.up.railway.app`), con las mismas variables de entorno.
3. **Redirección del cliente:** actualizar `API_BASE_URL` en la configuración remota de la app Flutter.
4. **Verificación:** endpoint de salud en HTTP 200 y prueba de atomicidad de cupos.

> Railway como plataforma de respaldo requiere tarjeta y genera el costo descrito en 5.2. Se usa como contingencia temporal ante una falla de Render, no como operación normal.

### 6.3 Parámetros de recuperación

| Parámetro | Valor | Condición |
|---|---|---|
| **RTO** | < 10 min | Despliegue de Railway ya creado; solo se redirige el cliente |
| **RPO** | 0 s | La base de datos (Supabase) permanece activa e independiente de la API |

---
