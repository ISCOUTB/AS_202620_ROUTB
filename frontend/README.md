# ROUTB - Frontend

Aplicación frontend de ROUTB, una plataforma de transporte compartido para estudiantes de la Universidad Tecnológica de Bolívar. Está construida con Flutter y se comunica con la API del backend mediante HTTP.

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

## Estructura del proyecto

```text
lib/
├── main.dart
├── core/
│   └── models/
│       └── user_role.dart
└── features/
    ├── auth/
    │   ├── screens/
    │   │   ├── login_screen.dart
    │   │   ├── role_selection_screen.dart
    │   │   └── splash_screen.dart
    │   └── services/
    │       └── auth_api.dart
    ├── home/
    │   └── screens/
    │       ├── dashboard_screen.dart
    │       └── home_screen.dart
    └── users/
        ├── screens/
        │   └── register_screen.dart
        └── services/
            └── user_service.dart
```
