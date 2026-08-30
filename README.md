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

---

## Instalación

Para preparar tu entorno local, sigue estos pasos en tu terminal.

### 1. Clona el repositorio

```bash
git clone https://github.com/ISCOUTB/AS_202620_ROUTB.git
```

### 2. Navega al directorio del proyecto

```bash
cd AS_202620_ROUTB
```

### Backend (FastAPI)

**3. Ingresa a la carpeta del backend**

```bash
cd backend
```

**4. Crea y activa el entorno virtual**

```powershell
python -m venv .venv
.\.venv\Scripts\activate
```

**5. Instala las dependencias**

```bash
pip install -r requirements.txt
```

### Frontend (Flutter)

**6. Vuelve a la raíz del proyecto y entra al frontend**

```bash
cd ../frontend
```

**7. Obtén las dependencias de Flutter**

```bash
flutter pub get
```

---

## Ejecución

### Arranque del Backend en un solo comando

Desde la carpeta `backend`, con el entorno virtual activo, inicia el servidor:

```bash
uvicorn app.main:app --reload
```

### Arranque del Frontend en un solo comando

Desde la carpeta `frontend`, con un emulador abierto o un celular conectado, inicia la aplicación:

```bash
flutter run
```

---

### Pruebas

Para validar el código del backend de forma local, asegúrate de estar en la carpeta `backend` con el entorno virtual activo y ejecuta:

```bash
pytest
```

### Prueba automatizada del recorrido completo (CI)

El recorrido de validación del flujo de autenticación se encuentra implementado y ejecutado en la nube mediante Integración Continua.

- **Archivo de prueba:** `backend/tests/test_registro.py`
- **Evidencia de ejecución (Success):** [Enlace a GitHub Actions Run #33330283493](https://github.com/ISCOUTB/AS_202620_ROUTB/actions/runs/33330283493)
