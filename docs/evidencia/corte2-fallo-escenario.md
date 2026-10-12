# Semana 10, corte 2: resiliencia ante fallo de proveedores

## Hipótesis

Ante timeout o fallo de OSRM, el backend entrega el fallback existente sin
cachearlo; el endpoint conserva sus respuestas contractuales y no produce
respuestas `500` por el fallo externo. El timeout de OSRM es configurable.

## Montaje previsto

- Backend local, PostgreSQL de pruebas y mismo commit durante cada comparación.
- Proveedor externo simulado con `TimeoutError`; no se modifica OSRM real.
- Calentar el servicio y realizar `N=50` solicitudes al endpoint afectado.
- Registrar el código HTTP y `duration_ms` estructurado del middleware.

## Variables y umbrales

- Independiente: proveedor responde / proveedor falla.
- Dependientes: código HTTP, resultado validado por el esquema y latencia.
- Controladas: base de pruebas, carga, configuración y commit.
- Criterios: `500=0`, respuestas válidas según OpenAPI y `p95 < 3.99 s`.

El resultado numérico y el hash se completan en
[`corte2-fallo-medicion.md`](corte2-fallo-medicion.md) al ejecutar la medición.
La línea base histórica se cita desde `metricas-escenario-calidad.md`; no se
reescribe evidencia anterior.
