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
- **Evidencia de ejecución (Success):** [GitHub Actions Run #36037874215](https://github.com/ISCOUTB/AS_202620_ROUTB/actions/runs/36037874215)

### Análisis de SonarCloud

El análisis de calidad de código se realiza automáticamente con SonarCloud.

- **Enlace:** [ROUTB en SonarCloud](https://sonarcloud.io/dashboard?id=ISCOUTB_AS_202620_ROUTB)

---

## Despliegue en la nube

### Estado actual

El backend está desplegado y accesible públicamente por HTTPS:

- **URL base:** [https://as-202620-routb.onrender.com](https://as-202620-routb.onrender.com)
- **Health check:** [https://as-202620-routb.onrender.com/health](https://as-202620-routb.onrender.com/health)
- **Evidencia de verificación externa:** [docs/evidencia/despliegue-externo.md](docs/evidencia/despliegue-externo.md)

### Piezas desplegadas

Ambas plataformas se usan en su plan gratuito, sin tarjeta de crédito.

| Pieza | Dónde se ejecuta | Proveedor | Decisión |
|---|---|---|---|
| API Backend | Web Service en contenedor Docker | [Render](https://render.com) | [ADR 0005](docs/adr/0005-plataforma-de-despliegue.md) |
| Base de datos | PostgreSQL 15 administrado | [Supabase](https://supabase.com) | [ADR 0006](docs/adr/0006-base-de-datos-supabase.md) |

La app móvil se ejecuta en el dispositivo del usuario y consume la API por HTTPS. El detalle completo está en la [Vista de despliegue](docs/arc42/07_vista_de_despliegue.md).

### Variables de entorno

| Variable | Para qué sirve | De dónde sale el valor | Dónde se configura |
|---|---|---|---|
| `DATABASE_URL` | Cadena de conexión con la que la API accede a la base de datos (SSL requerido) | Datos de conexión del proyecto, en el panel de Supabase | Panel de Render (Environment) |
| `JWT_SECRET_KEY` | Clave secreta con la que la API firma los tokens de autenticación | Se genera una cadena aleatoria (ver paso 4) | Panel de Render (Environment) |

Ejemplo de formato, sin valores reales:

```env
DATABASE_URL=postgresql://<USUARIO>:<CONTRASENA>@<HOST>:<PUERTO>/<BASE_DE_DATOS>
JWT_SECRET_KEY=<cadena-aleatoria-larga>
```

Los secretos no se guardan en el repositorio: se cargan únicamente en el panel de Render.

### Pasos para recrear el entorno desde cero

**Requisitos previos:** cuentas gratuitas en GitHub, Supabase y Render; acceso al repositorio; Python instalado para ejecutar las migraciones.

**1. Crear la base de datos en Supabase**

1. En [supabase.com](https://supabase.com) crea un proyecto nuevo (plan Free) y guarda la contraseña de la base de datos.
2. En el panel del proyecto busca los datos de conexión a la base de datos: los necesitarás para la variable `DATABASE_URL`.

**2. Crear las tablas (migraciones)**

Desde tu equipo, en la carpeta `backend`, con las dependencias instaladas y `DATABASE_URL` apuntando a Supabase:

```bash
cd backend
pip install -r requirements.txt
export DATABASE_URL="<tu cadena de Supabase>"   # PowerShell: $env:DATABASE_URL="<tu cadena de Supabase>"
alembic upgrade head
```

**3. Crear el servicio en Render**

1. En [render.com](https://render.com) conecta tu cuenta de GitHub.
2. Elige **New → Web Service** y selecciona el repositorio del proyecto.
3. Configura el servicio: entorno **Docker** (que use `backend/Dockerfile`), instancia **Free** y, en las opciones avanzadas, **Health Check Path** con el valor `/health`.
4. Antes de pulsar **Create Web Service**, agrega las variables de entorno del paso 4.

**4. Cargar las variables de entorno**

Al crear el servicio (o después, en su sección **Environment**), define `DATABASE_URL` (paso 1) y `JWT_SECRET_KEY`. Para generar esta última:

```bash
python -c "import secrets; print(secrets.token_urlsafe(32))"
```

**5. Desplegar**

Render construye la imagen a partir de `backend/Dockerfile` y arranca el servicio. Espera a que su estado sea **Live**.

**6. Verificar**

Reemplaza la URL por la de tu servicio (si recreas el entorno, será distinta a la de arriba):

```bash
curl https://as-202620-routb.onrender.com/health
# Respuesta esperada: {"status":"ok"}

curl -i https://as-202620-routb.onrender.com/trips/
# Respuesta esperada: HTTP 200
```

La documentación interactiva de la API queda disponible en `/docs`.

> En el plan gratuito de Render, si el servicio estuvo 15 minutos sin tráfico, la primera petición puede tardar entre 30 y 50 segundos. Es normal; las siguientes responden con rapidez.

---

## Calidad y métricas

La calidad de rendimiento se verifica con una métrica consultable: el percentil 95 de la latencia de `GET /trips/` debe ser menor a 3,99 s. El escenario, la fuente de datos, la consulta, el umbral y la medición realizada están en [docs/metricas.md](docs/metricas.md).