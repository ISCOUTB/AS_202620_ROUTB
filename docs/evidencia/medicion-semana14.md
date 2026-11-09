# Evidencia: medición del escenario de rendimiento (Semana 14)

## 1. Escenario medido y umbral

- **Atributo de calidad:** Rendimiento (tiempo de búsqueda de viajes).
- **Escenario declarado:** un pasajero consulta los viajes disponibles mediante
  `GET /trips/` en condiciones normales de operación; el sistema procesa la
  solicitud y muestra los resultados.
- **Referencia:** [arc42 sección 10.2, fila Rendimiento](../arc42/10_requisitos_de_calidad.md#102-escenarios-de-calidad)
  y [sección 10.1, objetivo ≤ 3,99 s](../arc42/10_requisitos_de_calidad.md#101-resumen-de-los-requisitos-de-calidad--árbol-de-utilidad).
- **Umbral:** **p95 < 3,99 s (3.990 ms)** para respuestas HTTP `200`.
  El umbral no se cambió después de medir.

## 2. Procedimiento

- **Herramienta:** [`scripts/medir_rendimiento.py`](../../scripts/medir_rendimiento.py),
  escrito en Python 3.14 con `httpx`. El script hace el calentamiento, ejecuta
  las rondas, valida que todas las respuestas sean `200` y guarda el resultado
  crudo en JSON.
- **Carga:** 100 peticiones **secuenciales** por ronda, 3 rondas, 300 peticiones
  válidas en total. Cada petición usa una conexión HTTP persistente del cliente
  (`httpx.Client`), por lo que el tiempo incluye el viaje de red pero no el
  arranque de un proceso `curl` por petición.
- **Calentamiento:** `GET /health` y espera de 5 s antes de la primera ronda.
- **Repeticiones:** 3 rondas independientes; se reporta el p95 de cada una y se
  contrasta el p95 más alto contra el umbral.
- **Cálculo del percentil:** rango más cercano, `ceil(n × 0,95) − 1`, igual que
  el procedimiento documentado en
  [`metricas-escenario-calidad.md`](metricas-escenario-calidad.md).
- **Respuestas no válidas:** cualquier código distinto de `200` aborta la ronda;
  no se mezclan errores con tiempos.

Comandos ejecutados desde la raíz del repositorio:

```powershell
# Entorno desplegado
backend\.venv\Scripts\python.exe scripts\medir_rendimiento.py `
  --url https://routb.iscoutb.dev/trips/ `
  --warmup-url https://routb.iscoutb.dev/health `
  --label "Dokploy (producción)" `
  --requests 100 --repetitions 3 --warmup-seconds 5 `
  --output docs/evidencia/medicion-semana14-dokploy.json

# Entorno local con datos sembrados (ver sección 3.2)
backend\.venv\Scripts\python.exe scripts\medir_rendimiento.py `
  --url http://127.0.0.1:8014/trips/ `
  --warmup-url http://127.0.0.1:8014/health `
  --label "Local (API Windows + PostgreSQL de pruebas remoto)" `
  --requests 100 --repetitions 3 --warmup-seconds 5 `
  --output docs/evidencia/medicion-semana14-local.json
```

## 3. Entorno de la medición

### 3.1 Medición principal: despliegue en Dokploy

| Dato | Valor |
|---|---|
| Tipo | **Desplegado** (externo, por HTTPS) |
| URL | `https://routb.iscoutb.dev` |
| Servicio | API FastAPI en Dokploy, `info.version = 0.9.0` |
| Comprobación previa | `GET /health` → `{"status":"ok"}` |
| Datos devueltos por `GET /trips/` | Lista vacía (`[]`) en las 300 respuestas: no había viajes activos para la fecha de la medición |
| Base de datos | Supabase de producción (no se inspeccionó directamente) |
| Fecha y hora | 2026-11-08, 23:15–23:19 (America/Bogota); 2026-11-09, 04:15–04:19 UTC |

**Limitación declarada:** la medición ocurre sobre el despliegue real, pero con
una carga útil vacía. Mide el camino completo de `GET /trips/` (autenticación
opcional, consulta a la base y serialización de una lista vacía), no el costo de
serializar muchos viajes. Por eso se complementa con la medición local de 3.2.

### 3.2 Medición complementaria: API local con datos sembrados

| Dato | Valor |
|---|---|
| Tipo | **Local** (API en el equipo) con base de datos de pruebas remota |
| URL | `http://127.0.0.1:8014` |
| Sistema operativo | Windows 11 Home Single Language, versión 10.0.26300 |
| CPU | Intel Core 5 210H, 8 núcleos físicos / 12 lógicos |
| RAM | 15,6 GB |
| Python | 3.14.6 |
| Backend | commit `bd4cd8f` (HEAD al medir) + artefactos de esta entrega |
| FastAPI / Uvicorn | 0.141.1 / 0.41.0 |
| SQLAlchemy / GeoAlchemy2 | 2.0.54 / 0.20.0 |
| Base de datos | PostgreSQL 17.6 en Supabase, proyecto de **pruebas**, región `us-west-2` (pooler, puerto 6543) |
| Datos | 5 viajes activos sembrados con `scripts/sembrar_viajes_medicion.py` para la fecha de la medición; `GET /trips/` devolvió 5 elementos en cada respuesta |
| Fecha y hora | 2026-11-08, 23:24–23:33 (America/Bogota); 2026-11-09, 04:24–04:33 UTC |

**Limitación declarada:** la API corre en el equipo local, pero la base de datos
es un proyecto de pruebas alojado en Supabase (us-west-2). El tiempo incluye la
latencia de red entre el equipo y esa base; no representa un PostgreSQL local ni
el Supabase de producción. La medición principal para el umbral es la de 3.1;
esta sirve para comprobar el comportamiento con carga útil no vacía.

## 4. Resultados

### 4.1 Dokploy (producción)

| Ronda | N | Mínimo | Promedio | p95 | Máximo |
|---|---:|---:|---:|---:|---:|
| 1 | 100 | 614,96 ms | 628,63 ms | **631,76 ms** | 1.149,44 ms |
| 2 | 100 | 614,46 ms | 623,05 ms | **631,48 ms** | 677,35 ms |
| 3 | 100 | 614,36 ms | 621,87 ms | **630,40 ms** | 701,92 ms |

- **p95 más alto de las rondas:** **631,76 ms**.
- **Umbral:** 3.990 ms.
- **Resultado:** **CUMPLE**.
- **Conclusión:** en el despliegue de Dokploy, el 95 % de las consultas de
  viajes respondió en menos de 632 ms, muy por debajo del umbral de 3,99 s. La
  conclusión aplica a una carga útil vacía; la medición con 5 viajes se reporta
  en 4.2.

### 4.2 Local con datos sembrados

| Ronda | N | Mínimo | Promedio | p95 | Máximo |
|---|---:|---:|---:|---:|---:|
| 1 | 100 | 1.434,20 ms | 1.568,76 ms | **2.470,48 ms** | 2.500,34 ms |
| 2 | 100 | 1.416,87 ms | 1.632,67 ms | **2.472,40 ms** | 6.775,08 ms |
| 3 | 100 | 1.425,77 ms | 1.820,89 ms | **2.564,52 ms** | 8.732,68 ms |

- **p95 más alto de las rondas:** **2.564,52 ms**.
- **Umbral:** 3.990 ms.
- **Resultado:** **CUMPLE**.
- **Conclusión:** en la medición local con 5 viajes, el p95 más alto fue
  2.564,52 ms, por debajo de 3.990 ms. Los máximos de 6,8 s y 8,7 s son
  compatibles con pausas aisladas del pooler de la base de pruebas remota
  (Supabase, `us-west-2`) y no mueven el p95 por encima del umbral; aun así, este
  entorno no representa producción y la medición principal para el umbral es la
  de 3.1.

## 5. Contraste con el umbral

| Medición | Entorno | p95 más alto | Umbral | Conclusión |
|---|---|---:|---:|---|
| Semana 14 principal | Dokploy (producción), carga útil vacía | **631,76 ms** | 3.990 ms | **CUMPLE** |
| Semana 14 complementaria | Local con 5 viajes y PostgreSQL de pruebas remoto | **2.564,52 ms** | 3.990 ms | **CUMPLE** |

La conclusión explícita de la entrega es: **el escenario de Rendimiento cumple
el umbral p95 < 3,99 s en el entorno desplegado**. La medición local con datos
confirma que el sistema sigue por debajo del umbral cuando la respuesta contiene
viajes, aunque su valor absoluto está dominado por la latencia de la base de
pruebas remota.

## 6. Comparación con mediciones anteriores

| Medición | Fecha | Entorno | Herramienta | p95 | Resultado |
|---|---|---|---|---|---|
| Línea base | 2026-09-26 | Render (externo) | PowerShell + `curl`, 100 peticiones | 585,10 ms | Cumple |
| Semana 9 | 2026-10-03 | Render (externo) | PowerShell + `curl`, 100 peticiones | 697,82 ms | Cumple |
| **Semana 14 principal** | **2026-11-08** | **Dokploy (externo)** | **`httpx`, 100 × 3** | **631,76 ms** | **Cumple** |
| Semana 14 complementaria | 2026-11-08 | Local + PostgreSQL de pruebas remoto | `httpx`, 100 × 3 | 2.564,52 ms | Cumple |

Las cifras no son estrictamente comparables entre sí: las mediciones de Render
usaron un proceso `curl` nuevo por petición, mientras que la de la Semana 14 usa
una conexión persistente. Aun así, las tres mediciones externas quedan por
debajo del umbral y la de Dokploy es del mismo orden que la línea base.

## 7. Reproducibilidad

Cualquier persona con acceso al repositorio y a `backend/.env` puede repetir la
medición:

1. **Entorno desplegado:** ejecutar el primer comando de la sección 2. No
   requiere credenciales porque `GET /trips/` es público.
2. **Entorno local:** aplicar migraciones y sembrar los viajes en la base de
   pruebas:
   ```powershell
   cd backend
   $env:TESTING = "1"
   .\.venv\Scripts\python.exe -m alembic upgrade head
   cd ..
   backend\.venv\Scripts\python.exe scripts\sembrar_viajes_medicion.py --count 5
   ```
3. **Levantar la API local** en otra terminal:
   ```powershell
   cd backend
   $env:TESTING = "1"
   $env:PYTHONPATH = "."
   .\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8014
   ```
4. **Medir** desde la raíz con el segundo comando de la sección 2.
5. **Limpiar** los viajes sembrados:
   ```powershell
   backend\.venv\Scripts\python.exe scripts\sembrar_viajes_medicion.py --clean
   ```

Los resultados crudos quedan versionados en:

- [`medicion-semana14-dokploy.json`](medicion-semana14-dokploy.json)
- [`medicion-semana14-local.json`](medicion-semana14-local.json)

El script imprime la tabla de cada ronda y escribe el JSON con los tiempos, los
códigos HTTP, el número de elementos de la carga útil y el entorno de ejecución.

## 8. Trazabilidad

- **Escenario y umbral:** [arc42 §10.2](../arc42/10_requisitos_de_calidad.md#102-escenarios-de-calidad).
- **Aspecto medido:** fila 1 de [`docs/aspectos.md`](../aspectos.md), columna
  *Evidencia*.
- **Señalamientos y deuda:** [arc42 §11.4](../arc42/11_riesgos_y_deuda_tecnica.md#114-señalamientos-de-la-revisión-entre-pares-y-de-la-revisión-externa).
- **Instrumentación interna:** middleware `structured_logging_middleware` de
  [`backend/app/main.py`](../../backend/app/main.py), que registra `duration_ms`
  por petición.
- **Artefactos de medición:** scripts y JSON enlazados en las secciones 2 y 7.
