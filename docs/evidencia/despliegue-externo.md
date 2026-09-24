# Evidencia de Despliegue en la Nube y Verificación de Disponibilidad Externa

## 1. Contexto de la Prueba

Conforme a lo establecido en el **ADR 0005** y los escenarios de calidad de **ROUTB**, el backend se desplegó en un entorno contenerizado público utilizando **Render (Web Service - Free Tier)** conectado a **Supabase (PostgreSQL 15)**.

Para validar que el servicio es efectivamente alcanzable desde fuera de la red de la universidad y sin requerir VPN ni autenticación de red local, se ejecutó una consulta HTTP al endpoint de diagnóstico de salud (`/health`).

- **URL Pública del Backend:** `https://as-202620-routb.onrender.com`
- **Endpoint Verificado:** `https://as-202620-routb.onrender.com/health`
- **Protocolo de Transporte:** HTTPS con terminación TLS gestionada por Cloudflare / Render.

---

## 2. Comando y Salida de Ejecución

A continuación se registra la ejecución real del comando `curl` realizada desde una terminal externa:

```powershell
PS C:\Windows\System32> curl.exe -i https://as-202620-routb.onrender.com/health
HTTP/1.1 200 OK
Date: Thu, 24 Sep 2026 18:12:15 GMT
Content-Type: application/json
Transfer-Encoding: chunked
Connection: keep-alive
cf-cache-status: DYNAMIC
rndr-id: cae3eaf0-eb4f-4cc0
Server: cloudflare
vary: Accept-Encoding
x-render-origin-server: uvicorn
CF-RAY: a403c19a1d4c6ebd-BOG
alt-svc: h3=":443"; ma=86400

{"status":"ok"}
```

---

## 3. Análisis de Resultados

| Parámetro | Valor Obtenido | Criterio / Esperado | Estado |
|---|---|---|---|
| **Código HTTP** | `200 OK` | `200 OK` | ✅ Cumple |
| **Cuerpo de Respuesta** | `{"status":"ok"}` | JSON válido con status ok | ✅ Cumple |
| **Servidor de Origen** | `uvicorn` (`x-render-origin-server`) | Servidor ASGI del contenedor Docker | ✅ Cumple |
| **Identificador de Despliegue** | `rndr-id: cae3eaf0-eb4f-4cc0` | Instancia activa en Render Cloud | ✅ Cumple |
| **Región de Salida CDN** | `BOG` (Bogotá, Colombia) | Acceso externo enrutado vía Cloudflare | ✅ Cumple |
| **Fecha / Hora de Verificación** | `Thu, 24 Sep 2026 18:12:15 GMT` | Tiempo de corte de la iteración actual | ✅ Cumple |

---

## 4. Trazabilidad

- **Decisión de Arquitectura:** [ADR 0005 - Plataforma de despliegue](../adr/0005-plataforma-de-despliegue.md)
- **Infraestructura como Código:** [backend/Dockerfile](../../backend/Dockerfile), [render.yaml](../../render.yaml)
- **Estimación de Costo:** [docs/evidencia/costo_mensual.md](costo_mensual.md)
- **Pruebas Automatizadas:** [backend/tests/test_health.py](../../backend/tests/test_health.py)
