# Evidencia S7 · Detección de cambio incompatible en el contrato de API

**Criterio:** La prueba de contrato falla ante un cambio incompatible (*breaking change*).  
**Archivo de prueba:** [`backend/tests/test_openapi_contract.py`](../../backend/tests/test_openapi_contract.py)  
**Test específico:** `test_contract_detects_incompatible_breaking_change`

---

## 1. Estado nominal: ambas pruebas en verde

Ejecutando la suite completa con el contrato `docs/openapi.json` v0.2.0 y la implementación FastAPI en la misma versión:

```
platform win32 -- Python 3.14.6, pytest-9.0.1, pluggy-1.6.0
rootdir: backend

tests/test_openapi_contract.py::test_openapi_contract_matches_implementation      PASSED [ 50%]
tests/test_openapi_contract.py::test_contract_detects_incompatible_breaking_change PASSED [100%]

============================== 2 passed in 9.10s ==============================
```

`test_contract_detects_incompatible_breaking_change` **pasa** precisamente porque el verificador interno (`_assert_contract_matches`) detectó correctamente el `AssertionError` que la prueba esperaba mediante `pytest.raises(AssertionError)`.

---

## 2. Cómo funciona la detección

El test simula un cambio incompatible en tiempo de ejecución, **sin alterar el código ni el contrato real**:

```python
# backend/tests/test_openapi_contract.py  (líneas 54-64)
def test_contract_detects_incompatible_breaking_change() -> None:
    """Demuestra que un cambio incompatible en la API rompe la prueba de contrato (requisito S7)."""
    contract = _load_contract()
    incompatible_impl = copy.deepcopy(app.openapi())

    # Simular la eliminación de una ruta clave (/trips/)
    if "/trips/" in incompatible_impl.get("paths", {}):
        del incompatible_impl["paths"]["/trips/"]

    with pytest.raises(AssertionError):
        _assert_contract_matches(contract, incompatible_impl)
```

El mutante `incompatible_impl` elimina la ruta `/trips/` del schema generado por FastAPI. El verificador compara rutas del contrato contra las de la implementación mutada y lanza el `AssertionError`.

---

## 3. Error capturado ante el cambio incompatible

El siguiente error es producido por `_assert_contract_matches` al comparar el contrato original con la implementación que tiene `/trips/` eliminada:

```
AssertionError: Ruta '/trips/' del contrato no encontrada en la implementación
```

**Rutas declaradas en `docs/openapi.json` (contrato):**

```
/users/  /trips/  /trips/my-trips  /trips/{trip_id}  /trips/{trip_id}/cancel
/trips/{trip_id}/reservations  /auth/login  /auth/me
/requests/trips/{trip_id}  /requests/{request_id}/accept  /requests/{request_id}/reject
/health  /
```

**Rutas en la implementación mutada (con breaking change):**

```
/users/  /trips/my-trips  /trips/{trip_id}  /trips/{trip_id}/cancel
/trips/{trip_id}/reservations  /auth/login  /auth/me
/requests/trips/{trip_id}  /requests/{request_id}/accept  /requests/{request_id}/reject
/health  /
```

`/trips/` fue eliminada → el verificador lo detecta y falla inmediatamente.

---

## 4. Qué ocurriría en CI si un breaking change llegara al repositorio

El paso del pipeline en [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml) que ejecuta pytest es:

```yaml
- name: Ejecutar pruebas unitarias y de contrato OpenAPI
  working-directory: backend
  run: pytest -v
```

Ante un cambio incompatible real (ej. eliminar o renombrar una ruta en el código de FastAPI sin actualizar `docs/openapi.json`), `test_openapi_contract_matches_implementation` devolvería un `AssertionError` con salida similar a:

```
FAILED tests/test_openapi_contract.py::test_openapi_contract_matches_implementation

AssertionError: Ruta '/trips/' del contrato no encontrada en la implementación
```

- **Exit code:** `1` → GitHub Actions marca el *job* como ❌ fallido.  
- **Pull request bloqueado:** no puede integrarse a `master` hasta que el fallo sea corregido.  
- **Efecto:** el contrato actúa como barrera de integración continua que obliga al equipo a actualizar `docs/openapi.json` de forma explícita y deliberada ante cualquier cambio de superficie de la API.

---

## 5. Otros tipos de cambio incompatible que la prueba detecta

| Cambio incompatible | Verificación en `_assert_contract_matches` | Error resultante |
| :--- | :--- | :--- |
| Eliminar una ruta (ej. `/trips/`) | `assert ruta in implementation["paths"]` | `Ruta '/trips/' del contrato no encontrada en la implementación` |
| Eliminar un método HTTP (ej. `POST /users/`) | `assert metodo in implementation["paths"][ruta]` | `Método 'POST' en '/users/' no encontrado en la implementación` |
| Reducir códigos de respuesta documentados | `set(contrato_op["responses"].keys()) <= set(impl_op["responses"].keys())` | `Códigos de respuesta no coinciden en POST /users/` |
| Eliminar un esquema de datos (ej. `TripResponse`) | `assert schema_name in impl_schemas` | `Esquema 'TripResponse' falta en components.schemas` |
| Desincronizar versión entre contrato e implementación | `assert contract["info"]["version"] == implementation["info"]["version"]` | `La versión de la API no coincide` |
