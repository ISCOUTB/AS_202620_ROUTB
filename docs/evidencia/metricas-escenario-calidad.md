# Métricas de calidad — Rendimiento de la consulta de viajes

Este documento define la métrica de rendimiento de ROUTB y la asocia a un escenario de calidad de la arquitectura. Especifica su **escenario**, **fuente de datos**, **consulta de cálculo** y **umbral de cumplimiento**, e incluye una **medición real** sobre el despliegue en Render.

---

## 1. Escenario de calidad asociado

- **Atributo de calidad:** Rendimiento (tiempo de búsqueda de viajes).
- **Referencia arc42:** [Sección 10.2 — Escenarios de calidad (fila Rendimiento)](../arc42/10_requisitos_de_calidad.md#102-escenarios-de-calidad) y [Sección 10.1 — Árbol de utilidad (Tiempo de búsqueda, objetivo ≤ 3,99 s)](../arc42/10_requisitos_de_calidad.md#101-resumen-de-los-requisitos-de-calidad--árbol-de-utilidad).
- **Enunciado:**
  > En condiciones normales de operación, cuando un pasajero consulta los viajes disponibles (`GET /trips/`), el sistema procesa la solicitud y muestra los resultados de modo que el **95 % de las solicitudes (percentil 95, p95) responde en menos de 3,99 segundos**.
- **Endpoint medido:** `GET /trips/`.

---

## 2. Fuente de datos

La métrica se calcula con dos mediciones. La **interna** es la métrica oficial; la **externa** la confirma desde el punto de vista del usuario.

| Medición | Qué mide | Fuente |
|---|---|---|
| **Interna (oficial)** | Tiempo que tarda la aplicación en procesar cada petición | Registros de actividad de la API en Render |
| **Externa (complementaria)** | Tiempo total que percibe quien hace la petición, incluida la red | Script de PowerShell con `curl` |

### 2.1 Registros de actividad de la API

- **Origen:** el middleware `structured_logging_middleware` de [`backend/app/main.py`](/backend/app/main.py) mide con `time.perf_counter()` cuánto tarda cada petición y escribe una línea JSON por petición.
- **Dónde se consultan:** pestaña **Logs** del servicio en Render, o con `render logs`.
- **Retención:** limitada por el plan de Render (7 días en Hobby, 14 en Professional). Por eso los registros se exportan y se guardan en el repositorio el día de la medición.
- **Formato de cada registro:**

```json
{
  "timestamp": "2026-09-24T18:12:15.123456+00:00",
  "method": "GET",
  "path": "/trips/",
  "status_code": 200,
  "duration_ms": 48.25,
  "client_ip": "203.0.113.10"
}
```

### 2.2 Medición externa

Un script de PowerShell envía 100 peticiones a `GET /trips/` sobre el despliegue público y guarda el código HTTP y el tiempo total de cada una. Como incluye la latencia de red, suele dar valores más altos que la medición interna.

---

## 3. Consulta de cálculo

### 3.1 Medición interna con logs de Render

Este procedimiento tiene **tres fases separadas**: la última depende de un archivo que se prepara manualmente entre la fase 1 y la fase 2, así que no se ejecuta todo de corrido.

#### Fase 1 — Generar tráfico

```powershell
$url = "https://as-202620-routb.onrender.com"

curl.exe -s "$url/health" | Out-Null
Start-Sleep -Seconds 5

1..100 | ForEach-Object {
    curl.exe -s -o NUL "$url/trips/"
    Write-Progress -Activity "Generando tráfico a /trips/" -Status "$_ de 100" -PercentComplete $_
}
Write-Progress -Activity "Generando tráfico a /trips/" -Completed
```

#### Fase 2 — Preparar `render_access.log`

> **Detenerse aquí.** La fase 3 necesita este archivo ya creado; si se ejecuta antes, el script falla porque el archivo no existe todavía.

1. Entrar al servicio en Render → pestaña **Logs**.
2. Filtrar por el texto `/trips/` en la barra de búsqueda.
3. Ajustar el rango de tiempo para cubrir el momento en que se generó el tráfico (fase 1).
4. Seleccionar y copiar las líneas visibles (el panel no tiene botón de exportación).
5. Pegar el contenido copiado en un archivo de texto nuevo llamado `render_access.log`, guardado en la misma carpeta donde se ejecutará la fase 3.

#### Fase 3 — Calcular la métrica

```powershell
$tiempos = @(
    Get-Content render_access.log |
        ForEach-Object { $_ -replace '^\d{4}-\d{2}-\d{2}T\S+\s+', '' } |
        Where-Object { $_.StartsWith('{') } |
        ForEach-Object { $_ | ConvertFrom-Json } |
        Where-Object { $_.path -eq '/trips/' -and $_.method -eq 'GET' -and $_.status_code -eq 200 } |
        ForEach-Object { [double]$_.duration_ms / 1000 } |
        Sort-Object
)

$n = $tiempos.Count

if ($n -gt 0) {
    $idx = [math]::Ceiling($n * 0.95) - 1
    $promedio = ($tiempos | Measure-Object -Average).Average

    "--------------------------------"
    "Resultados de rendimiento"
    "--------------------------------"
    "N = $n"
    "Mínimo:   $([math]::Round($tiempos[0], 4)) s"
    "Promedio: $([math]::Round($promedio, 4)) s"
    "p95:      $([math]::Round($tiempos[$idx], 4)) s"
    "Máximo:   $([math]::Round($tiempos[-1], 4)) s"
} else {
    "No se encontraron peticiones coincidentes."
}
```

### 3.2 Medición externa en PowerShell

```powershell
$url = "https://as-202620-routb.onrender.com"

# 1. Calentar el servicio
curl.exe -s "$url/health" | Out-Null
Start-Sleep -Seconds 5

# 2. 100 peticiones a la consulta de viajes
$resultados = 1..100 | ForEach-Object {
    curl.exe -s -o NUL -w '%{http_code} %{time_total}' "$url/trips/"
}

# Mostrar resultados individuales
$resultados

# 3. Obtener tiempos de respuestas 200
$tiempos = $resultados |
    Where-Object { $_ -like "200 *" } |
    ForEach-Object { [double](($_ -split ' ')[1]) } |
    Sort-Object

$n = $tiempos.Count

if ($n -gt 0) {
    $idx = [math]::Ceiling($n * 0.95) - 1
    $promedio = ($tiempos | Measure-Object -Average).Average

    "--------------------------------"
    "Resultados de rendimiento"
    "--------------------------------"
    "N = $n"
    "Mínimo:   $([math]::Round($tiempos[0], 4)) s"
    "Promedio: $([math]::Round($promedio, 4)) s"
    "p95:      $([math]::Round($tiempos[$idx], 4)) s"
    "Máximo:   $([math]::Round($tiempos[-1], 4)) s"
} else {
    "No se encontraron peticiones con código 200."
}
```

---

## 4. Umbral de cumplimiento

| Indicador | Condición | Estado |
|---|---|---|
| **p95 de `GET /trips/`** | **p95 < 3,99 s** | **CUMPLE** |
| **p95 de `GET /trips/`** | **p95 ≥ 3,99 s** | **NO CUMPLE** |

Condiciones de validez de la medición:

- Solo se cuentan respuestas con código `200`.
- Mínimo 100 peticiones por medición.
- Servicio calentado antes de medir.

> **Arranque en frío:** según el [ADR 0005](../adr/0005-render-plataforma-de-despliegue.md), la primera petición tras un periodo de inactividad en Render puede tardar decenas de segundos. Ese tiempo ocurre antes de que el middleware empiece a medir, así que esta métrica **no lo captura**. Por eso el servicio se calienta antes de medir, y el arranque en frío se evalúa por separado en la [verificación de disponibilidad externa](../evidencia/despliegue-externo.md).

---

## 5. Medición realizada
 
Ambas mediciones se hicieron el 26 de septiembre de 2026 sobre `GET https://as-202620-routb.onrender.com/trips/`.
 
| Dato | Interna (oficial) | Externa (complementaria) |
|---|---|---|
| Fuente | Registros de Render | Script de PowerShell con `curl` |
| Peticiones con código 200 (N) | 100 | 100 |
| Mínimo | 193,10 ms | 426,80 ms |
| Promedio | 206,40 ms | 507,70 ms |
| **p95** | **219,80 ms** | **585,10 ms** |
| Máximo | 222,90 ms | 724,40 ms |
| Umbral | < 3.990 ms | < 3.990 ms |
| **Resultado** | **CUMPLE** | **CUMPLE** |
 
**Cómo leer los resultados:** en ambos casos el p95 queda muy por debajo del umbral. La medición externa es más lenta porque suma el viaje de red entre quien consulta y Render; la interna muestra el tiempo real de trabajo de la aplicación.
 
**Chequeo de salud de Render:** las líneas de `/health` que aparecen en los registros (cada 5 segundos, en menos de 4 ms) se excluyen del cálculo, porque el filtro solo toma `/trips/`.
 
---

## 6. Trazabilidad con la arquitectura

- **Requisito de calidad:** [arc42 sección 10.2 (Rendimiento)](../arc42/10_requisitos_de_calidad.md#102-escenarios-de-calidad).
- **Instrumentación de código:** middleware en [`backend/app/main.py`](/backend/app/main.py).
- **Decisiones relacionadas:** [ADR 0003](../adr/0003-control-atomico-de-cupos.md), [ADR 0005](../adr/0005-render-plataforma-de-despliegue.md) y [ADR 0006](../adr/0006-base-de-datos-supabase.md).
- **Evidencia de ejecución en la nube:** [Verificación de disponibilidad externa](../evidencia/despliegue-externo.md).