# ROUTB

Plataforma de transporte compartido para estudiantes de la Universidad Tecnológica de Bolívar.

## Contenido

- [ROUTB](#routb)
  - [Contenido](#contenido)
  - [Descripción](#descripción)
  - [Equipo de desarrollo](#equipo-de-desarrollo)
  - [Tecnologías](#tecnologías)
  - [Inicio rápido](#inicio-rápido)
  - [Pruebas y calidad de código](#pruebas-y-calidad-de-código)
    - [Pruebas locales](#pruebas-locales)
    - [Pruebas automatizadas (CI)](#pruebas-automatizadas-ci)
    - [Análisis de SonarCloud](#análisis-de-sonarcloud)
  - [Despliegue en la nube](#despliegue-en-la-nube)
    - [Estado actual](#estado-actual)
    - [Piezas desplegadas](#piezas-desplegadas)
    - [Variables de entorno](#variables-de-entorno)
    - [Pasos para recrear el entorno desde cero](#pasos-para-recrear-el-entorno-desde-cero)
  - [Calidad y métricas](#calidad-y-métricas)

---

## Descripción

La aplicación permite consultar a estudiantes conductores y rutas disponibles, conocer la cantidad de cupos libres y reservar un cupo antes del viaje, haciendo que la organización del transporte sea más rápida y eficiente.

El objetivo es reducir los tiempos de espera y mejorar la coordinación entre estudiantes conductores y pasajeros, facilitando la organización del transporte dentro de la comunidad universitaria.

La descripción completa del problema se encuentra en [Problema](docs/problema.md).

---

## Equipo de desarrollo

- Diego Baron
- Junior Orozco
- Keiner Mendivil
- Julian Manjarrez

---

## Tecnologías

| Tecnología | Uso |
|---|---|
| **Flutter** | Aplicación móvil |
| **FastAPI** | Backend y API |
| **PostgreSQL (Supabase)** | Base de datos relacional administrada |
| **Docker** | Contenedor del backend (`backend/Dockerfile`) |
| **Dokploy** | Hosting del backend en la nube |
| **Git / GitHub** | Control de versiones |

---

## Inicio rápido

Para iniciar el proyecto, ejecuta el script correspondiente según tu sistema operativo en el directorio raíz del proyecto:

- **Windows:** `start.bat`
- **Linux/Mac:** `start.sh`

Para **compilar la app Android** hace falta además
`frontend/android/app/google-services.json`, descargado de la consola de Firebase
del proyecto del equipo. El archivo está excluido de Git (`.gitignore`), así que
cada persona lo baja por su cuenta: el plugin `com.google.gms.google-services` se
aplica siempre y sin ese archivo el build de Android falla.

---

## Pruebas y calidad de código

### Pruebas locales

Para validar el código del backend de forma local, asegúrate de estar en la carpeta `backend` con el entorno virtual activo y ejecuta:

```bash
pytest
```

### Pruebas automatizadas (CI)

El recorrido de validación del flujo de autenticación se encuentra implementado y ejecutado en la nube mediante Integración Continua.

- **Archivos de prueba:**
  - [Prueba de salud](backend/tests/test_health.py)
  - [Prueba de registro](backend/tests/test_registro.py)
  - [Prueba de cupos](backend/tests/test_cupos.py)
  - [Prueba de viajes](backend/tests/test_trips_flow.py)
  - [Prueba de contrato](backend/tests/test_openapi_contract.py)
- **Evidencia de ejecución (Success):** [GitHub Actions Run #36063583782](https://github.com/ISCOUTB/AS_202620_ROUTB/actions/runs/36063583782)
  
  **Conclusion de la última ejecución:** La ejecución de las pruebas automatizadas ha sido exitosa, lo que indica que el código cumple con los estándares de calidad establecidos.

### Análisis de SonarCloud

El análisis de calidad se ejecuta desde GitHub Actions con el scanner oficial
de SonarCloud cuando el secreto `SONAR_TOKEN` está configurado en el repositorio
(Settings → Secrets and variables → Actions). En pull requests sin acceso a
secretos, el paso se omite.

- **Enlace:** [ROUTB en SonarCloud](https://sonarcloud.io/dashboard?id=ISCOUTB_AS_202620_ROUTB)

---

## Despliegue en la nube

### Estado actual

El backend está desplegado y accesible públicamente por HTTPS:

- **URL base:** [https://routb.iscoutb.dev](https://routb.iscoutb.dev)
- **Health check:** [https://routb.iscoutb.dev/health](https://routb.iscoutb.dev/health)

**Evidencia:** Al entrar a los links de verificación, se puede observar que el servicio está funcionando correctamente. Si se necesita verificar más a fondo, se puede consultar toda la evidencia en [docs/evidencia/despliegue-dokploy.md](docs/evidencia/despliegue-dokploy.md)

### Piezas desplegadas

El backend corre en un servidor propio administrado con **Dokploy**, la base de datos se guarda en el plan gratuito de Supabase y la geocodificación usa la capa gratuita de Google Maps Platform. Ninguna de estas piezas genera costo para el proyecto dentro de los límites documentados.

| Pieza | Dónde se ejecuta | Proveedor | Decisión |
|---|---|---|---|
| API Backend | Contenedor Docker en servidor propio | [Dokploy](https://dokploy.com) | [ADR 0015](docs/adr/0015-dokploy-plataforma-de-despliegue.md) |
| Base de datos | PostgreSQL 15 administrado | [Supabase](https://supabase.com) | [ADR 0006](docs/adr/0006-base-de-datos-supabase.md) |
| Geocodificación y rutas | Cliente Flutter | [Google Maps Platform](https://mapsplatform.google.com) | [ADR 0018](docs/adr/0018-google-maps-platform-frontend.md) |
| Renderizado del mapa | Cliente Flutter | OpenStreetMap + `flutter_map` | [ADR 0019](docs/adr/0019-renderizado-mapas-flutter-map-osm.md) |

El manifiesto de referencia del contenedor y de sus variables es [`compose.lab.yaml`](compose.lab.yaml). No se aplica automáticamente: los valores reales de los secretos, el dominio y la política de despliegue se administran desde el panel de Dokploy.

> Se mantiene la restricción **RC-04 (costo recurrente $0.00 USD y cero tarjetas de crédito)**:
> el uso de Dokploy en este proyecto no genera costo y el servidor donde se ejecuta tampoco
> genera facturación para el equipo. Ver
> [Restricciones de arquitectura](docs/arc42/02_restricciones_de_arquitectura.md#25-restricciones-comerciales-y-de-alcance)
> y [costo mensual](docs/evidencia/costo_mensual.md).

### Variables de entorno

| Variable | Para qué sirve | De dónde sale el valor | Dónde se configura |
|---|---|---|---|
| `DATABASE_URL` | Cadena de conexión con la que la API accede a la base de datos (SSL requerido) | Datos de conexión del proyecto, en el panel de Supabase | Dokploy (Environment del servicio) |
| `JWT_SECRET_KEY` | Clave secreta con la que la API firma los tokens de autenticación | Se genera una cadena aleatoria (ver paso 4) | Dokploy (Environment del servicio) |
| `ROUTING_TIMEOUT_SECONDS` | Tiempo máximo de espera por petición a OSRM (segundos) | `1.4` por defecto; ajustable según latencia y disponibilidad del proveedor | Dokploy (Environment del servicio) |
| `FCM_PROJECT_ID` | Identificador del proyecto de Firebase desde el que se envían las notificaciones push | Consola de Firebase del proyecto del equipo | Dokploy (Environment del servicio) |
| `FCM_SERVICE_ACCOUNT_B64` | Credencial de la cuenta de servicio de Firebase (el JSON en base64) con la que la API firma cada envío | Consola de Firebase → *Cuentas de servicio* → *Generar nueva clave privada* | Dokploy (Environment del servicio) |
| `GOOGLE_MAPS_API_KEY` | Clave de Google Maps Platform para geocodificación, autocompletado y rutas en el cliente Flutter | Google Cloud → APIs y servicios → Credenciales; debe estar restringida por plataforma y APIs | `frontend/.env` (ignorado por git) e inyección con `--dart-define-from-file=.env` |

### Pasos para recrear el entorno desde cero

**Requisitos:** cuentas gratuitas en GitHub, Supabase y Render, y Python instalado.

1. **Base de datos (Supabase):** crea un proyecto (plan Free) y copia la cadena de conexión del panel; la usarás como `DATABASE_URL`.
2. **Migraciones:** en `backend`, con las dependencias instaladas y `DATABASE_URL` exportada, ejecuta `alembic upgrade head`.
3. **Servicio (Render):** *New → Web Service* → selecciona el repo → entorno **Docker** (`backend/Dockerfile`), instancia **Free**, **Health Check Path** = `/health`.
4. **Variables de entorno** en Render → *Environment*: `DATABASE_URL` (paso 1), `JWT_SECRET_KEY` (genera una con `python -c "import secrets; print(secrets.token_urlsafe(32))"`) y `ROUTING_TIMEOUT_SECONDS` (por defecto `3.0`, declarada en `render.yaml`).
5. **Verificar:** espera a que el servicio quede **Live** y prueba:
   ```bash
   curl https://as-202620-routb.onrender.com/health
   curl -i https://as-202620-routb.onrender.com/trips/
   ```

> En el plan gratuito de Render, tras 15 min sin tráfico la primera petición puede tardar 30-50 s; las siguientes responden con normalidad. La documentación interactiva de la API está en `/docs`.

---

## Calidad y métricas

La calidad de rendimiento se verifica con una métrica consultable: el percentil 95 de la latencia de `GET /trips/` debe ser menor a 3,99 s. El escenario, la fuente de datos, la consulta, el umbral y la medición realizada están en [Metricas frente a escenario de calidad](docs/evidencia/metricas-escenario-calidad.md).
