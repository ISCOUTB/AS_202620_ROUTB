# Evidencia de despliegue en la nube y verificación de disponibilidad externa

## 1. Contexto de la prueba

Conforme a lo establecido en el **ADR 0005** y los escenarios de calidad de **ROUTB**, el backend se desplegó en un entorno contenerizado público utilizando **Render (Web Service - Free Tier)** conectado a **Supabase (PostgreSQL 15)**.

Para validar que el servicio es efectivamente alcanzable desde fuera de la red de la universidad y sin requerir VPN ni autenticación de red local, se ejecutó una consulta HTTP al endpoint de diagnóstico de salud (`/health`).

- **URL Pública del Backend:** `https://as-202620-routb.onrender.com`
- **Endpoint Verificado:** `https://as-202620-routb.onrender.com/health`
- **Protocolo de Transporte:** HTTPS con terminación TLS gestionada por Cloudflare / Render.

---

## 2. Comando y salida de ejecución

Se ejecutó el siguiente comando, capturando en una sola llamada la respuesta HTTP completa y el tiempo total de respuesta:

```powershell
curl.exe -i -w " codigo=%{http_code} tiempo=%{time_total}s" https://as-202620-routb.onrender.com/health
```

Se obtuvo la siguiente salida, que incluye encabezados HTTP, cuerpo de respuesta y métricas de tiempo:

```
HTTP/1.1 200 OK
Date: Sat, 26 Sep 2026 02:13:36 GMT
Content-Type: application/json
Transfer-Encoding: chunked
Connection: keep-alive
cf-cache-status: DYNAMIC
rndr-id: 1f8fe663-f055-4e94
Server: cloudflare
vary: Accept-Encoding
x-render-origin-server: uvicorn
CF-RAY: a40ec0150eab707c-BOG
alt-svc: h3=":443"; ma=86400

{"status":"ok"} codigo=200 tiempo=0.299997s
```

---

## 3. Análisis de resultados

| Parámetro | Valor Obtenido | Criterio / Esperado | Estado |
|---|---|---|---|
| **Código HTTP** | `200 OK` | `200 OK` | ✅ Cumple |
| **Cuerpo de Respuesta** | `{"status":"ok"}` | JSON válido con status ok | ✅ Cumple |
| **Servidor de Origen** | `uvicorn` (`x-render-origin-server`) | Servidor ASGI del contenedor Docker | ✅ Cumple |
| **Tiempo de Respuesta** | `0.299997s` | Tiempo total medido con `curl -w %{time_total}` | ✅ Cumple |
| **Identificador de Despliegue** | `rndr-id: 1f8fe663-f055-4e94` | Instancia activa en Render Cloud | ✅ Cumple |
| **Región de Salida CDN** | `BOG` (Bogotá, Colombia) | Acceso externo enrutado vía Cloudflare | ✅ Cumple |
| **Fecha / Hora de Verificación** | `Sat, 26 Sep 2026 02:13:36 GMT` | Tiempo de corte de la iteración actual | ✅ Cumple |

---

## 4. Trazabilidad

- **Decisión de Arquitectura:** [ADR 0005 - Plataforma de despliegue](../adr/0005-plataforma-de-despliegue.md)
- **Infraestructura como Código:** [backend/Dockerfile](../../backend/Dockerfile), [render.yaml](../../render.yaml)
- **Estimación de Costo:** [docs/evidencia/costo_mensual.md](costo_mensual.md)
- **Pruebas Automatizadas:** [backend/tests/test_health.py](../../backend/tests/test_health.py)
