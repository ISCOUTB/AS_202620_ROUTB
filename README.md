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
| **Render** | Hosting del backend en la nube |
| **Git / GitHub** | Control de versiones |

---

## Inicio rápido

Para iniciar el proyecto, ejecuta el script correspondiente según tu sistema operativo en el directorio raíz del proyecto:

- **Windows:** `start.bat`
- **Linux/Mac:** `start.sh`

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

El análisis de calidad de código se realiza automáticamente con SonarCloud.

- **Enlace:** [ROUTB en SonarCloud](https://sonarcloud.io/dashboard?id=ISCOUTB_AS_202620_ROUTB)

---

## Despliegue en la nube

### Estado actual

El backend está desplegado y accesible públicamente por HTTPS:

- **URL base:** [https://as-202620-routb.onrender.com](https://as-202620-routb.onrender.com)
- **Health check:** [https://as-202620-routb.onrender.com/health](https://as-202620-routb.onrender.com/health)

**Evidencia:** Al entrar a los links de verificación, se puede observar que el servicio está funcionando correctamente. Si se necesita verificar más a fondo, se puede consultar toda la evidencia en [docs/evidencia/despliegue-externo.md](docs/evidencia/despliegue-externo.md)

### Piezas desplegadas

Ambas plataformas que prestan servicio se usan en su plan gratuito.

| Pieza | Dónde se ejecuta | Proveedor | Decisión |
|---|---|---|---|
| API Backend | Web Service en contenedor Docker | [Render](https://render.com) | [ADR 0005](docs/adr/0005-plataforma-de-despliegue.md) |
| Base de datos | PostgreSQL 15 administrado | [Supabase](https://supabase.com) | [ADR 0006](docs/adr/0006-base-de-datos-supabase.md) |

### Variables de entorno

| Variable | Para qué sirve | De dónde sale el valor | Dónde se configura |
|---|---|---|---|
| `DATABASE_URL` | Cadena de conexión con la que la API accede a la base de datos (SSL requerido) | Datos de conexión del proyecto, en el panel de Supabase | Panel de Render (Environment) |
| `JWT_SECRET_KEY` | Clave secreta con la que la API firma los tokens de autenticación | Se genera una cadena aleatoria (ver paso 4) | Panel de Render (Environment) |

### Pasos para recrear el entorno desde cero

**Requisitos:** cuentas gratuitas en GitHub, Supabase y Render, y Python instalado.

1. **Base de datos (Supabase):** crea un proyecto (plan Free) y copia la cadena de conexión del panel; la usarás como `DATABASE_URL`.
2. **Migraciones:** en `backend`, con las dependencias instaladas y `DATABASE_URL` exportada, ejecuta `alembic upgrade head`.
3. **Servicio (Render):** *New → Web Service* → selecciona el repo → entorno **Docker** (`backend/Dockerfile`), instancia **Free**, **Health Check Path** = `/health`.
4. **Variables de entorno** en Render → *Environment*: `DATABASE_URL` (paso 1) y `JWT_SECRET_KEY` (genera una con `python -c "import secrets; print(secrets.token_urlsafe(32))"`).
5. **Verificar:** espera a que el servicio quede **Live** y prueba:
   ```bash
   curl https://as-202620-routb.onrender.com/health
   curl -i https://as-202620-routb.onrender.com/trips/
   ```

> En el plan gratuito de Render, tras 15 min sin tráfico la primera petición puede tardar 30-50 s; las siguientes responden con normalidad. La documentación interactiva de la API está en `/docs`.

---

## Calidad y métricas

La calidad de rendimiento se verifica con una métrica consultable: el percentil 95 de la latencia de `GET /trips/` debe ser menor a 3,99 s. El escenario, la fuente de datos, la consulta, el umbral y la medición realizada están en [docs/metricas.md](docs/evidencia/metricas.md).