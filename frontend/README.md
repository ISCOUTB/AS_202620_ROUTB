# ROUTB - Frontend

Aplicación frontend de ROUTB, una plataforma de transporte compartido para estudiantes de la Universidad Tecnológica de Bolívar. Está construida con Flutter y se comunica con la API del backend mediante solicitudes HTTP.

## Requisitos

- Flutter SDK compatible con Dart `^3.13.1`.
- Un dispositivo Android/iOS, un emulador o un navegador compatible.
- Backend de ROUTB desplegado en ""https://as-202620-routb.onrender.com""

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

## Estructura

El código se organiza en tres capas, para que las pantallas no dependan de HTTP ni de `shared_preferences`.

```
lib/
  main.dart                 Arranca la app y monta las dependencias.
  app/                      Raíz: tema, transiciones y resolución de sesión.
  core/                     Configuración, modelos, red, sesión, tema y widgets.
  features/                 Un módulo por flujo: auth, driver, passenger, trips.
```

- **`core/theme`** concentra el diseño. `RoutbPalette` guarda los colores,
  sombras y degradados como `ThemeExtension`, y `RoutbTheme` arma los dos
  `ThemeData` a partir de ella. Ningún widget fija colores literales: los lee
  con `context.palette`.
- **`core/widgets`** tiene las piezas reutilizables que corresponden a cada
  elemento de la interfaz (tarjeta, botón, campo, chip, hoja, aviso, cupos).
- **`core/network`** tiene `ApiClient`, que centraliza la cabecera de
  autenticación, el límite de espera y la traducción de fallos a `ApiException`.
- **`features/*/data`** tiene los repositorios: no saben nada de widgets.

## Backend

La dirección del backend se resuelve en un único archivo: [`lib/core/config/api_config.dart`](lib/core/config/api_config.dart). Por defecto apunta a la API desplegada en Render:

```
https://as-202620-routb.onrender.com
```

Los repositorios (`auth_repository.dart` y `trip_repository.dart`) leen siempre de ahí, así que cambiar de plataforma es editar una constante.

### Configurar la dirección del backend

Para sobreescribirla en tiempo de compilación, usa `--dart-define`:

```bash
# Backend local, en Flutter Web
flutter run -d chrome --dart-define=ROUTB_API_BASE_URL=http://127.0.0.1:8000
```

Para probar contra un despliegue propio, apunta a su dirección **HTTPS**:

```bash
flutter run --dart-define=ROUTB_API_BASE_URL=https://mi-backend.example.com
```

> **Importante:** el manifest de Android declara `android:usesCleartextTraffic="false"`, así que las peticiones **HTTP planas están bloqueadas en Android**, tanto en debug como en release. El backend local en `http://127.0.0.1:8000` solo es alcanzable desde **Flutter Web** (`flutter run -d chrome`). Esta restricción es intencional: sostiene el escenario de calidad de seguridad de la app.

### Levantar el backend local (opcional)

Si necesitas probar cambios del backend antes de desplegarlos:

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

> **Nota:** el repositorio incluye un `docker-compose.yml` en la raíz como alternativa para levantar la base de datos y el backend en contenedores.

> **Las pruebas no dependen de este paso.** `pytest` usa su propia variable `DATABASE_URL_TEST` y se ejecuta en CI sobre un PostgreSQL aislado; consulta [`.github/workflows/ci.yml`](../.github/workflows/ci.yml).

## Ejecución del frontend

Desde la raíz del repositorio puedes usar el script que automatiza la instalación y la ejecución:

```bash
# Windows
start.bat

# Mac/Linux
./start.sh
```

O directamente:

```bash
cd frontend
flutter run
```

También puedes indicar un dispositivo específico:

```bash
flutter devices
flutter run -d <device-id>
```

## Pruebas y análisis estático

```bash
# Análisis estático
flutter analyze

# Pruebas
flutter test
```

Las pruebas cubren la lógica que depende de datos del backend —el parseo de la
hora de salida, la resolución de barrios, los cupos, la fase del viaje y el
estado del botón de reserva— y el comportamiento de los widgets base en los dos
temas.

## Build

Para generar una versión distribuible:

```bash
# Android
flutter build apk

# Web
flutter build web
```

Se puede fijar la dirección del backend en el build:

```bash
flutter build apk --dart-define=ROUTB_API_BASE_URL=https://mi-backend.example.com
```

> Los builds de **release** de Android requieren `gen_snapshot` (la herramienta que convierte el código Dart en nativo). En equipos con **App Control / WDAC** activo, ese binario puede quedar bloqueado y el build falla con `Una directiva de Control de aplicaciones bloqueó este archivo`. El build de **web** no lo usa, así que sirve como verificación alternativa. El desarrollo con `flutter run` no se ve afectado: el modo debug no requiere esa herramienta.
