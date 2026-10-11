# AGENTS.md

ROUTB es una plataforma de transporte compartido para estudiantes de la
Universidad Tecnológica de Bolívar. Backend en FastAPI + PostgreSQL con
autenticación JWT; frontend en Flutter. La documentación está en español y los
nombres de código siguen las convenciones de Python y Dart.

Este archivo es para agentes de código. La guía para personas (instalación
desde cero, contexto general) está en `README.md`.

## Cómo trabajar aquí

- Haz cambios pequeños y enfocados, compatibles con la arquitectura existente.
  No reformatees ni reorganices archivos que no tengan relación con la tarea.
- Conserva el idioma y el estilo del archivo que editas.
- Si dudas entre dos enfoques, o la tarea toca algo de la sección "Pregunta
  antes de", pregunta antes de actuar.
- Si no pudiste ejecutar una prueba o un comando, dilo en el reporte final y
  explica por qué. No lo des por aprobado.
- ROUTB no maneja pagos, tarifas ni aportes por cupo. No agregues campos,
  endpoints ni pantallas de precios.

## Mapa del repositorio

| Ruta | Contenido |
|---|---|
| `backend/app/core/` | Configuración, conexión a base de datos y dependencias compartidas |
| `backend/app/modules/<dominio>/` | Lógica de negocio por dominio, en capas de aplicación, dominio e infraestructura |
| `backend/migrations/versions/` | Migraciones Alembic |
| `backend/tests/` | Pruebas, incluida la prueba de contrato OpenAPI y la de concurrencia de cupos |
| `frontend/lib/app/` | Raíz de la app, rutas, tema y resolución de sesión |
| `frontend/lib/core/` | Configuración, red, modelos, sesión, tema y widgets reutilizables |
| `frontend/lib/features/` | Flujos de negocio; cada uno con su capa `data/` (repositorios) |
| `docs/` | Decisiones (ADR), evidencias y documentación |
| `.github/workflows/ci.yml` | CI: pruebas del backend y construcción de la imagen Docker |

## Comandos

### Backend (desde `backend/`, con el entorno virtual `.venv` activo)

```bash
python -m pip install --only-binary :all: --require-hashes -r requirements.txt
uvicorn app.main:app --reload                       # servidor local
pytest -q                                           # toda la suite
pytest tests/<archivo>.py -k <nombre> -q            # una prueba concreta
alembic upgrade head                                # aplicar migraciones
alembic revision --autogenerate -m "descripcion"    # nueva migración (revísala a mano)
```

- Las pruebas necesitan PostgreSQL y `DATABASE_URL_TEST`, que debe ser distinta
  de `DATABASE_URL`: el fixture de tests bloquea una coincidencia accidental.
- Las variables van en `backend/.env` (plantilla: `.env.example`): `DATABASE_URL`,
  `DATABASE_URL_TEST`, `JWT_SECRET_KEY`, `JWT_ALGORITHM`, `JWT_EXPIRE_MINUTES`.

### Frontend (desde `frontend/`)

```bash
flutter pub get
flutter run
flutter run -d chrome --dart-define=ROUTB_API_BASE_URL=http://127.0.0.1:8000   # web contra backend local
flutter analyze
flutter test
dart format --output=none --set-exit-if-changed lib test
flutter build web                                   # compilación de verificación
```

Si `dart format` modifica archivos, revisa el diff antes de continuar.

### Docker (desde la raíz)

```bash
docker compose up --build                           # PostgreSQL + backend (usa el .env de la raíz)
docker build -t routb-backend:local backend         # solo la imagen del backend
```

## Reglas del backend

- Los routers traducen HTTP y delegan. No pongas reglas de negocio ni consultas
  complejas en ellos; respeta la separación de capas de cada módulo.
- Si cambias el esquema: actualiza el modelo, crea una migración Alembic nueva y
  agrega pruebas. Nunca edites una migración que ya se aplicó en un ambiente
  compartido.
- Si cambias la API: actualiza las pruebas, la prueba de contrato OpenAPI y la
  documentación. Conserva rutas, respuestas y códigos HTTP existentes, salvo que
  el cambio sea intencional y esté cubierto por pruebas.
- Los cupos se descuentan con una actualización atómica condicionada en la base
  de datos (ADR 0003). No uses leer-y-luego-escribir ni agregues bloqueos de fila
  sin un ADR nuevo. Todo cambio en reservas o solicitudes debe seguir pasando
  `backend/tests/test_cupos.py`. Revisa también propiedad del viaje y
  disponibilidad.
- Valida entradas con los esquemas Pydantic y conserva las dependencias de
  autenticación y autorización existentes.
- Usa SQLAlchemy o consultas parametrizadas; nunca construyas SQL concatenando
  entrada del usuario.
- El hashing de contraseñas y la verificación de JWT viven en sus módulos
  actuales. No implementes criptografía propia.

## Reglas del frontend

- Las pantallas y widgets no hacen llamadas HTTP ni acceden a
  `shared_preferences`. El acceso a la API pasa por los repositorios de
  `features/*/data`, y estos por `core/network/ApiClient`, que centraliza
  autenticación, timeouts y la traducción de errores a `ApiException`.
- Colores y estilos salen de `context.palette`. Evita colores literales.
- La URL del backend se configura en `frontend/lib/core/config/api_config.dart`
  y se puede sobreescribir con `--dart-define=ROUTB_API_BASE_URL=...`.

## Seguridad y datos

- Nunca agregues al control de versiones secretos, contraseñas, tokens, archivos
  `.env`, bases de datos locales, artefactos de compilación ni carpetas de
  herramientas.
- No registres contraseñas, JWT, cadenas de conexión ni cuerpos sensibles. Los
  logs del middleware de acceso deben seguir siendo estructurados y sin esos
  datos.
- No relajes CORS, TLS, permisos de contenedor ni validaciones solo para hacer
  pasar una prueba.
- No ejecutes pruebas destructivas contra la base de datos de desarrollo.
- Las variables de producción se configuran en Render, nunca en el repositorio.
- No cambies dependencias sin justificarlo y sin actualizar su archivo.
  `requirements.txt` está fijado con hashes y debe seguir siendo reproducible.
- Mantén compatibilidad con las versiones de Python y Dart declaradas en
  `backend/Dockerfile`, `.github/workflows/ci.yml` y `frontend/pubspec.yaml`.
- No edites archivos generados: `frontend/.dart_tool/`, `frontend/build/`, los
  proyectos nativos generados por Flutter ni `__pycache__/`.

## Pregunta antes de

- Agregar, quitar o actualizar dependencias.
- Ejecutar `alembic downgrade`, borrar datos o correr `docker compose down -v`.
- Modificar `backend/Dockerfile`, `docker-compose.yml`, el CI o la configuración
  de despliegue.
- Hacer un cambio que rompa el contrato actual de la API.
- Hacer push o merge directo a `master`.

## Git

- La rama de trabajo es `Changes`. Antes de editar, comprueba con
  `git branch --show-current`; si no estás en `Changes`, no edites nada y avisa.
- Puedes usar `git status`, `git diff`, `git log` y `git branch --show-current`.
- Haz `git add`, `git commit` y `git push origin Changes` solo cuando la persona
  lo pida. Agrega archivos por nombre (nunca `git add .`), usa Conventional
  Commits (`feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `chore:`) y nunca
  `--amend`, `--force` ni `--no-verify`. Si el push falla, detente y avisa.
- No ejecutes ningún otro comando de git que modifique el repositorio (`merge`,
  `rebase`, `reset`, `stash`, `pull`, cambiar de rama). Los merges los hace la
  persona.

## Trampas conocidas

- Android bloquea el tráfico HTTP plano de forma intencional. Para un backend
  remoto usa HTTPS.
- Los builds de release de Android pueden requerir `gen_snapshot` y el sistema
  puede bloquearlos. Usa `flutter build web` como verificación alternativa y
  reporta la limitación.

## Antes de dar una tarea por terminada

1. Ejecuta lo que aplique al cambio:
   - Backend: `pytest -q`, y además `alembic upgrade head` si tocaste modelos o
     migraciones.
   - Frontend: `flutter analyze`, `flutter test` y el chequeo de `dart format`.
   - Docker: `docker build -t routb-backend:local backend` si tocaste el
     `Dockerfile`, `requirements.txt` o el arranque de la API.
2. Revisa `git diff`: sin secretos, artefactos ni cambios ajenos a la tarea.
3. Actualiza la documentación directamente afectada: endpoint, esquema, variable
   de entorno, comando, capas, despliegue, migraciones o decisión técnica (ADR
   en `docs/`).
4. Reporta qué cambiaste, cómo lo verificaste, qué no pudiste ejecutar y
   cualquier consideración de configuración o despliegue.