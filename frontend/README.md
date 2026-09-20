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

## Ejecución

Inicia primero el backend:

```bash
cd backend
.venv\Scripts\activate
pip install --only-binary :all: --require-hashes -r requirements.txt
uvicorn app.main:app --reload
```

Después, desde otra terminal, ejecuta el frontend:

```bash
cd frontend
flutter run
```

También puedes indicar un dispositivo específico:

```bash
flutter devices
flutter run -d <device-id>
```