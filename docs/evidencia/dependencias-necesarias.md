# Dependencias necesarias

Dependencias directas del backend (`backend/requirements.in`). El resto de paquetes en `requirements.txt` son transitivas y las resuelve `uv` automáticamente.

**Python:** 3.14

| Paquete | Versión | Propósito |
|---|---|---|
| fastapi | 0.141.1 | Framework web / API REST |
| uvicorn | 0.41.0 | Servidor ASGI para ejecutar FastAPI |
| pydantic | 2.13.5 | Validación y esquemas de datos |
| sqlalchemy | 2.0.54 | ORM y acceso a base de datos |
| alembic | 1.19.2 | Migraciones de base de datos |
| psycopg2-binary | 2.9.13 | Driver de PostgreSQL |
| bcrypt | 5.0.0 | Hash de contraseñas |
| PyJWT | 2.10.1 | Generación y validación de tokens JWT |
| python-dotenv | 1.2.3 | Carga de variables de entorno desde `.env` |
| httpx | 0.28.1 | Cliente HTTP (peticiones externas / pruebas) |
| pytest | 9.0.1 | Framework de pruebas |
| geoalchemy2 | 0.20.0 | Soporte geoespacial / PostGIS para SQLAlchemy |
| firebase-admin | 6.5.0 | Envío de notificaciones push con Firebase Cloud Messaging; credencial de servicio en `FCM_SERVICE_ACCOUNT_B64`. |

Dependencia directa de la app Flutter (`frontend/pubspec.yaml`):

| Paquete | Versión | Propósito |
|---|---|---|
| geolocator | 14.1.1 | Solicitar ubicación del dispositivo únicamente al pulsar «Usar mi ubicación». |
| firebase_core | ^4.2.0 | Inicialización de Firebase en Android. |
| firebase_messaging | ^16.0.3 | Registro de tokens y recepción de notificaciones push en Android. |
| flutter_local_notifications | ^19.4.2 | Mostrar avisos FCM cuando ROUTB está en primer plano. |

La compilación Android requiere `frontend/android/app/google-services.json` del
proyecto Firebase. El archivo está excluido de Git y se comparte por el canal
privado del equipo.

## Instalación

```bash
pip install --require-hashes -r backend/requirements.txt
```

## Regenerar `requirements.txt`

```bash
uv pip compile backend/requirements.in --python-version 3.14 --generate-hashes --output-file backend/requirements.txt
```
