# Evidencia del workflow de pruebas y del run de GitHub Actions

## 1. Línea exacta que invoca la prueba

Archivo: [../../.github/workflows/ci.yml](../../.github/workflows/ci.yml)

```yaml
- name: Ejecutar pruebas unitarias y de contrato OpenAPI
  working-directory: backend
  run: pytest -v
```

Ubicación exacta en el archivo:
- Línea 41: `- name: Ejecutar pruebas unitarias y de contrato OpenAPI`
- Línea 42: `working-directory: backend`
- Línea 43: `run: pytest -v`

---

## 2. URL del run exitoso

Archivo: [../../README.md](../../README.md)

En la sección de CI se documenta esta evidencia:

- **Run de GitHub Actions:** https://github.com/ISCOUTB/AS_202620_ROUTB/actions/runs/35476468042

---

## 3. Evidencia de salida del workflow

En la salida del job `test`, la ejecución de la etapa de pruebas reporta estas líneas de éxito:

```text
tests/test_openapi_contract.py::test_openapi_contract_matches_implementation PASSED [ 42%]
tests/test_openapi_contract.py::test_contract_detects_incompatible_breaking_change PASSED [ 57%]
```

Estas dos pruebas validan que:
- el contrato OpenAPI coincide con la implementación actual;
- el contrato detecta correctamente un cambio incompatible.

---

## 4. Verificación

Se verificó lo siguiente:
- la acción del workflow ejecuta `pytest -v` desde el backend;
- el run de GitHub Actions existe y está asociado a la rama del proyecto;
- la salida del log incluye las dos pruebas de contrato OpenAPI con resultado `PASSED`.

Fuentes consultadas:
- [.github/workflows/ci.yml](../../.github/workflows/ci.yml)
- [README.md](../../README.md)
- salida del job `test` en GitHub Actions

