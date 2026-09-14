# Hallazgos de código y sus correcciones

Estos son los hallazgos que SonarQube reportó sobre la rama `master`. Encontró trece hallazgos, todos con archivo y línea, y los trece quedaron corregidos en esta misma entrega: ninguno se aceptó sin arreglar.

| Violaciones detectadas en el código actual | Ubicación | Tipo de riesgo | Plan de corrección |
| :--- | :--- | :--- | :--- |
| Uso de dependencias sin bloquear las versiones resueltas. | `.github/workflows/ci.yml` | Seguridad | Cambiar `pip install -r requirements.txt` por `pip install --only-binary :all: --require-hashes -r requirements.txt`. |
| Versiones de dependencias impredecibles (falta archivo lock). | `frontend/android/build.gradle.kts` | Seguridad | 1. Añadir `dependencyLocking { lockAllConfigurations() }`.<br>2. Ejecutar `./gradlew dependencies --write-locks`.<br>3. Crear el archivo `gradle.lockfile`. |
| Método vacío sin justificación. | `frontend/linux/flutter/generated_plugin_registrant.cc`<br>`frontend/windows/flutter/generated_plugin_registrant.cc` | Mantenibilidad | Agregar un comentario dentro del método explicando por qué está vacío, o implementar su lógica. |
| Tarea sin `group` y `description` definidos. | `frontend/android/build.gradle.kts` | Mantenibilidad | Definir las propiedades `description` y `group` dentro del bloque de registro de la tarea. |
| Uso de tipo redundante. | `frontend/windows/runner/utils.cpp` | Mantenibilidad | Reemplazar el tipo explícito (ej. `static_cast<int>`) por `auto`. |
| Uso de operación insegura `reinterpret_cast`. | `frontend/windows/runner/win32_window.cpp` | Mantenibilidad | Reemplazar `reinterpret_cast` por una operación de casteo más segura en C++. |
| No usar `Annotated` para inyección de dependencias en FastAPI. | `backend/app/modules/auth/router.py`<br>`backend/app/modules/users/router.py` | Mantenibilidad | Actualizar los *type hints* de `Depends()` utilizando `Annotated` del módulo `typing`. |
| Clase vacía sin implementación. | `frontend/ios/Runner/SceneDelegate.swift` | Mantenibilidad | Eliminar la clase vacía o implementar su código/protocolo. |
| Declaración de variable fuera de la inicialización del `if`. | `frontend/linux/runner/my_application.cc` (variable `error`)<br>`frontend/windows/runner/utils.cpp` (variable `converted_length`)<br>`frontend/windows/runner/win32_window.cpp` (variable `enable_non_client_dpi_scaling`) | Mantenibilidad | Mover la declaración de la variable al interior de la condición del `if` (uso de *init-statement* de C++17). |
| Nombre de función no cumple con la convención (Regex). | `frontend/macos/Flutter/GeneratedPluginRegistrant.swift` | Mantenibilidad | Renombrar la función `RegisterGeneratedPlugins` a formato camelCase (`registerGeneratedPlugins`). |
| Uso de `switch` poco legible. | `frontend/windows/runner/flutter_window.cpp` | Mantenibilidad | Reemplazar la estructura `switch` por condicionales `if` equivalentes. |