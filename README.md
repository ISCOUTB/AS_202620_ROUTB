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

- **Archivos de prueba:** [`backend/tests/test_registro.py`](backend/tests/test_registro.py), [`backend/tests/test_cupos.py`](backend/tests/test_cupos.py), [`backend/tests/test_trips_flow.py`](backend/tests/test_trips_flow.py) y [`backend/tests/test_openapi_contract.py`](backend/tests/test_openapi_contract.py)
- **Evidencia de ejecución (Success):** [GitHub Actions Run #35476468042](https://github.com/ISCOUTB/AS_202620_ROUTB/actions/runs/35476468042)

### Analisis de SonarCloud
El análisis de calidad de código se realiza automáticamente con SonarCloud.
- **Enlace:** [ROUTB en SonarCloud](https://sonarcloud.io/dashboard?id=ISCOUTB_AS_202620_ROUTB)
