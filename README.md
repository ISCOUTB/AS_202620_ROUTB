# ROUTB

## Descripción

ROUTB es una plataforma diseñada para facilitar el transporte compartido entre los estudiantes de la Universidad Tecnológica de Bolívar.

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

- **Flutter** — Desarrollo de la aplicación móvil.
- **FastAPI** — Desarrollo del backend y API.
- **PostgreSQL** — Gestión de la base de datos.
- **Git / GitHub** — Control de versiones.

---

## Inicio rápido

Para iniciar el proyecto, ejecuta el script correspondiente según tu sistema operativo en el directorio raíz del proyecto:

- **Windows:** `start.bat`
- **Linux/Mac:** `start.sh`

### Pruebas

Para validar el código del backend de forma local, asegúrate de estar en la carpeta `backend` con el entorno virtual activo y ejecuta:

```bash
pytest
```

### Prueba automatizada del recorrido completo (CI)

El recorrido de validación del flujo de autenticación se encuentra implementado y ejecutado en la nube mediante Integración Continua.

- **Archivos de prueba:** [`Prueba de salud`](backend/tests/test_health.py),[`Prueba de registro`](backend/tests/test_registro.py), [`Prueba de cupos`](backend/tests/test_cupos.py), [`Prueba de viajes`](backend/tests/test_trips_flow.py) y [`Prueba de contrato`](backend/tests/test_openapi_contract.py)
- **Evidencia de ejecución (Success):** [GitHub Actions Run #36037874215](https://github.com/ISCOUTB/AS_202620_ROUTB/actions/runs/36037874215)

### Analisis de SonarCloud
El análisis de calidad de código se realiza automáticamente con SonarCloud.
- **Enlace:** [ROUTB en SonarCloud](https://sonarcloud.io/dashboard?id=ISCOUTB_AS_202620_ROUTB)

### Despliegue en la nube
El backend se encuentra desplegado y accesible públicamente vía HTTPS sobre Render:
- **URL Base:** [https://as-202620-routb.onrender.com](https://as-202620-routb.onrender.com)
- **Health Check:** [https://as-202620-routb.onrender.com/health](https://as-202620-routb.onrender.com/health)
- **Evidencia de verificación externa:** [docs/evidencia/despliegue-externo.md](docs/evidencia/despliegue-externo.md)

