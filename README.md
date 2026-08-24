
# ROUTB

## Descripción

ROUTB es una plataforma diseñada para facilitar el transporte compartido entre los estudiantes de la Universidad Tecnológica de Bolívar.

La aplicación permite consultar a estudiantes conductores y rutas disponibles, conocer la cantidad de cupos libres y reservar un cupo antes del viaje, haciendo que la organización del transporte sea más rápida y eficiente.

El objetivo es reducir los tiempos de espera y mejorar la coordinación entre estudiantes conductores y pasajeros, facilitando la organización del transporte dentro de la comunidad universitaria.

La descripción completa del problema se encuentra en [Problema](docs/problema.md).

---

## Equipo de Desarrollo
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

## Instalación

Para instalar la aplicación, sigue estos pasos en tu terminal:

1. Clona el repo: `git clone https://github.com/ISCOUTB/AS_202620_ROUTB.git`

2. Navega al directorio del proyecto: `cd AS_202620_ROUTB`

3. Navega al directorio del backend: `cd backend`

4. Crea un entorno virtual: `python -m venv .venv`

5. Activa el entorno virtual: `.venv\Scripts\Activate`

6. Instala las dependencias: `pip install -r requirements.txt`

## Ejecución

Para ejecutar la aplicación, sigue estos pasos:

1. Inicia el servidor: `uvicorn app.main:app --reload`

2. Ejecuta las pruebas ya automatizadas: `pytest`


