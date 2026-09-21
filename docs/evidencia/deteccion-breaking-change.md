# Evidencia de Detección de Cambios Incompatibles en CI (Semana 7)

**Proyecto:** ROUTB (`ISCOUTB/AS_202620_ROUTB`)  
**Rama:** `Changes`  
**Criterio de Evaluación:** Evidencia de que la prueba falla ante un cambio incompatible (`arqsw:evidencia-s7`).  
**Estado:** Cumple  

---

## 1. Resumen de Ejecuciones en GitHub Actions

| Estado | Evento / Descripción | Hash Commit | URL de la Run en GitHub Actions | Fecha y Hora (COT / UTC) |
| :--- | :--- | :--- | :--- | :--- |
| **❌ FAILURE (Rojo)** | Introducción de cambio incompatible en ruta `/trips/my-trips` | [`98bb629`](https://github.com/ISCOUTB/AS_202620_ROUTB/commit/98bb629f66f3be634ebac4b8e82afa5416d1f338) | [Ver Run en Rojo #35531242547](https://github.com/ISCOUTB/AS_202620_ROUTB/actions/runs/35531242547) | 2026-09-20 14:07 COT<br>(2026-09-20T19:07:03Z) |
| **✅ SUCCESS (Verde)** | Reversión del cambio incompatible y restauración de conformidad | [`6cda9e1`](https://github.com/ISCOUTB/AS_202620_ROUTB/commit/6cda9e1c75fe92a6df7a229a1b18d04847e3a936) | [Ver Run en Verde #35531321884](https://github.com/ISCOUTB/AS_202620_ROUTB/actions/runs/35531321884) | 2026-09-20 14:11 COT<br>(2026-09-20T19:11:20Z) |

---

## 2. Descripción del Cambio Incompatible Introducido

Para comprobar que la prueba de contrato en el pipeline es ejecutable y capaz de detener cambios que rompan el contrato con los consumidores, se introdujo un cambio incompatible real en el commit `98bb629`:

- **Archivo modificado:** `backend/app/modules/trips/infrastructure/router.py`
- **Modificación:** Se renombró la ruta `@router.get("/my-trips")` por `@router.get("/mis-viajes-incompatible")`.
- **Efecto:** El contrato OpenAPI versionado (`docs/openapi.json`) promete la existencia de la operación `GET /trips/my-trips`. Al no existir en la implementación de FastAPI, la prueba de contrato detectó la discrepancia inmediatamente.

---

## 3. Evidencia del Fallo en el Pipeline de CI (Run en Rojo)

El push a la rama `Changes` disparó automáticamente el workflow **CI ROUTB** (`.github/workflows/ci.yml`). 

En la ejecución **[Run #35531242547](https://github.com/ISCOUTB/AS_202620_ROUTB/actions/runs/35531242547)**, el paso *«Ejecutar pruebas unitarias y de contrato OpenAPI»* falló con el siguiente error:

```text

================================== FAILURES ===================================
________________ test_openapi_contract_matches_implementation _________________

    def test_openapi_contract_matches_implementation() -> None:
        """Verifica que la API implementada cumpla fielmente con el contrato OpenAPI versionado."""
        contract = _load_contract()
        implementation = app.openapi()
>       _assert_contract_matches(contract, implementation)

tests/test_openapi_contract.py:51: 
_ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _
>   assert ruta in implementation.get("paths", {}), f"Ruta '{ruta}' del contrato no encontrada en la implementación"
E   AssertionError: Ruta '/trips/my-trips' del contrato no encontrada en la implementación

tests/test_openapi_contract.py:31: AssertionError
Error: Process completed with exit code 1.
```

---

## 4. Restauración y Retorno a Estado Verde

Tras verificar que el pipeline detuvo la integración de la ruptura de contrato:

1. Se revirtió el cambio incompatible en el commit `6cda9e1`, restaurando `@router.get("/my-trips")`.
2. Se realizó el `push` a la rama `Changes`.
3. El workflow **CI ROUTB** se ejecutó en **[Run #35531321884](https://github.com/ISCOUTB/AS_202620_ROUTB/actions/runs/35531321884)**, completando con éxito todas las pruebas:
   ```text
   tests/test_openapi_contract.py::test_openapi_contract_matches_implementation PASSED [ 50%]
   tests/test_openapi_contract.py::test_contract_detects_incompatible_breaking_change PASSED [100%]
   ============================== 2 passed in 0.41s ==============================
   ```

---

## 5. Conclusión

Queda evidenciado que:
1. El contrato OpenAPI en `docs/openapi.json` gobierna de manera efectiva la implementación del backend.
2. La prueba de contrato en `.github/workflows/ci.yml` detecta cualquier cambio no documentado o incompatible.
3. El pipeline previene integraciones defectuosas garantizando la estabilidad de la API para los clientes móviles de ROUTB.
