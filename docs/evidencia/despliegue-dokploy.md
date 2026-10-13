# Evidencia de despliegue en Dokploy y verificación de disponibilidad externa

## 1. Contexto de la prueba

El backend de ROUTB se migró de Render a un servidor propio administrado con **Dokploy**, conforme a la decisión registrada en el [ADR 0015](../adr/0015-dokploy-plataforma-de-despliegue.md), que reemplaza al [ADR 0005](../adr/0005-render-plataforma-de-despliegue.md). La base de datos no cambió: sigue en **Supabase (PostgreSQL 15)** según el ADR 0006.

El objetivo de esta verificación es comprobar, desde fuera de la red de la universidad y sin VPN ni autenticación de red local, que el servicio es alcanzable por HTTPS y que responde correctamente.

- **URL Pública del Backend:** `https://routb.iscoutb.dev`
- **Endpoint Verificado:** `https://routb.iscoutb.dev/health`
- **Protocolo de Transporte:** HTTPS con terminación TLS gestionada por Dokploy, sobre un certificado emitido por Let's Encrypt.
- **Fecha y hora de la verificación:** 13 de octubre de 2026. Las mediciones se tomaron con el servicio ya activo; no se registró marca de tiempo por petición porque el objetivo era la disponibilidad, no la latencia instrumentada.

La verificación equivalente del despliegue anterior en Render se conserva intacta en
[despliegue-externo.md](despliegue-externo.md), que queda como registro histórico de aquel periodo.

---

## 2. Verificación de disponibilidad

### 2.1 Endpoint de salud

```powershell
curl.exe -i https://routb.iscoutb.dev/health
```

Respuesta obtenida:

```
HTTP/1.1 200 OK
Content-Type: application/json

{"status":"ok"}
```

### 2.2 Endpoint de negocio

```powershell
curl.exe -i https://routb.iscoutb.dev/trips/
```

Respuesta obtenida: `HTTP/1.1 200 OK` con el listado de viajes activos en JSON.

### 2.3 Certificado TLS

| Propiedad | Valor |
|---|---|
| Emisor | `CN=YR1, O=Let's Encrypt, C=US` |
| Protocolo | HTTPS en el puerto 443 |
| Renovación | Gestionada por Dokploy |

---

## 2.4 Recursos del servidor

Medición tomada del panel de monitoreo de Dokploy:

| Recurso | Valor |
|---|---|
| CPU | 7,59 % en uso |
| RAM | 3,82 GiB de 11,67 GiB |
| Disco | 34,89 GB de 76,45 GB |

Estas cifras corresponden al **servidor completo** (plataforma y API). El consumo
de memoria atribuible solo a la API **no está medido** y no se desglosa aquí.

El hecho de que la CPU se encuentre baja y la RAM en un tercio indica que el servidor
no está saturado, por lo que la latencia observada en la sección 3 no se explica por
contención de recursos del servidor.

---

## 3. Comportamiento de latencia

Uno de los motivos de la migración fue el arranque en frío del plan gratuito de Render (30 a 50 segundos tras 15 minutos sin tráfico), que afecta la experiencia del usuario aunque no lo capture la métrica de percentil 95.

Se realizaron cuatro peticiones consecutivas sin pausa entre ellas y se midió el tiempo total del lado del cliente:

| Petición | Código | Tiempo total |
|---|---|---|
| 1 | `200` | 689 ms |
| 2 | `200` | 681 ms |
| 3 | `200` | 688 ms |
| 4 | `200` | 683 ms |

**Resultado:** la latencia es estable y muy por debajo del umbral de 3,99 s. **Estas cuatro muestras no constituyen un percentil 95**; el procedimiento de medición de referencia del proyecto, con N=100, está en [metricas-escenario-calidad.md](metricas-escenario-calidad.md) y quedó ejecutado sobre Render.

> **Hipótesis sobre la latencia residual, sin medir.** Los ~680 ms podrían deberse a la
> apertura de una conexión nueva a la base de datos en cada petición, porque el motor SQLAlchemy
> está configurado con `poolclass=NullPool` (`backend/app/core/database.py`). **No se midió el
> tiempo de conexión por separado**, así que la causa sigue sin confirmarse. El servidor, en todo caso, no está saturado: la CPU ronda el 7,6 %.

---

## 4. Análisis de resultados

| Parámetro | Valor obtenido | Criterio / esperado | Estado |
|---|---|---|---|
| **Código HTTP de `/health`** | `200 OK` | `200 OK` | Cumple |
| **Cuerpo de respuesta** | `{"status":"ok"}` | JSON válido con status ok | Cumple |
| **Código HTTP de `/trips/`** | `200 OK` | `200 OK` | Cumple |
| **Dominio propio** | `routb.iscoutb.dev` | Dominio bajo control del proyecto | Cumple |
| **Certificado TLS** | Emitido por Let's Encrypt | HTTPS válido | Cumple |
| **Arranque en frío** | No aplica: Dokploy no suspende el contenedor por inactividad | Sin latencia de arranque | Cumple |
| **Latencia estable** | ~680 ms por petición (4 muestras, sin p95 calculado) | p95 por debajo de 3,99 s | Parcial |

---

## 5. Verificaciones de seguridad pendientes

Esta sección deja registrado un hallazgo **detectado y aún no corregido** en el momento de
la verificación. No forma parte de los criterios de disponibilidad, pero se documenta para
que no se pierda de vista:

- `GET /users/` respondía `200` **sin autenticación** y sin `response_model`, por lo que
  devolvía la tabla completa de usuarios incluyendo el campo `hashed_password`.
- `POST /trips/{trip_id}/reservations` respondía **sin autenticación**, permitiendo descontar
  cupos de cualquier viaje sin dejar registro.
- `PATCH /trips/{trip_id}/cancel` no exigía token; la comprobación de propiedad se
  omitía cuando el llamador era anónimo.
- La configuración de CORS usaba `allow_origins=["*"]` junto con
  `allow_credentials=True`, de modo que cualquier origen externo podía leer esas
  respuestas desde el navegador de un visitante.

La corrección de estos puntos es independiente del despliegue. **No existe todavía un ticket,
ADR ni entrada en el registro de riesgos que los recoja**, de modo que en su estado actual
contradicen el Aspecto 3 de [aspectos.md](../aspectos.md) ("todo endpoint sensible valida
identidad mediante JWT"). Hasta que se cierren, esa afirmación del Aspecto 3 debe leerse
como requisito y no como estado verificado.

---

## 6. Trazabilidad

- **Decisión de arquitectura:** [ADR 0015 - Dokploy como plataforma de despliegue](../adr/0015-dokploy-plataforma-de-despliegue.md)
- **Decisión reemplazada:** [ADR 0005 - Render como plataforma de despliegue](../adr/0005-render-plataforma-de-despliegue.md)
- **Contenedor:** [backend/Dockerfile](../../backend/Dockerfile) (sin cambios respecto a la imagen que construía Render)
- **Configuración del cliente:** [frontend/lib/core/config/api_config.dart](../../frontend/lib/core/config/api_config.dart)
- **Vista de despliegue:** [arc42/07_vista_de_despliegue.md](../arc42/07_vista_de_despliegue.md)
- **Estimación de costo:** [costo_mensual.md](costo_mensual.md)
- **Pruebas automatizadas:** [backend/tests/test_health.py](../../backend/tests/test_health.py)
