# ROUTB - Frontend

Aplicación frontend de ROUTB, una plataforma de transporte compartido para estudiantes de la Universidad Tecnológica de Bolívar. Está construida con Flutter y se comunica con la API del backend mediante solicitudes HTTP.

## Requisitos

- Flutter SDK compatible con Dart `^3.13.1`.
- Un dispositivo Android/iOS, un emulador o un navegador compatible.
- Backend de ROUTB ejecutándose localmente en el puerto `8000`.

Verifica la instalación con:

```bash
flutter doctor
```

## Instalación

Desde la raíz del repositorio:

```bash
cd frontend
flutter pub get
```

## Backend

El frontend necesita el backend corriendo en `http://localhost:8000`.

```bash
cd backend
```

Crea el entorno virtual (solo la primera vez):

```bash
python -m venv .venv
```

Actívalo:

```bash
# Windows
.venv\Scripts\activate
# Mac/Linux
source .venv/bin/activate
```

Instala las dependencias:

```bash
pip install --only-binary :all: --require-hashes -r requirements.txt
```

Configura las variables de entorno copiando la plantilla y completando los valores:

```bash
cp .env.example .env
```

Inicia el servidor:

```bash
uvicorn app.main:app --reload
```

> **Nota:** también puedes usar el script `start.bat` (Windows) o `start.sh` (Mac/Linux) en la raíz del repositorio para automatizar estos pasos y levantar el frontend a continuación. Requiere que el `.venv` ya exista y las variables de entorno estén configuradas.
>
> El repositorio también incluye un `docker-compose.yml` en la raíz como alternativa para levantar la base de datos y el backend en contenedores.

## Ejecución del frontend

Con el backend ya corriendo, desde otra terminal:

```bash
cd frontend
flutter run
```

También puedes indicar un dispositivo específico:

```bash
flutter devices
flutter run -d <device-id>
```

## Build

Para generar una versión distribuible:

```bash
# Android
flutter build apk

# Web
flutter build web
```