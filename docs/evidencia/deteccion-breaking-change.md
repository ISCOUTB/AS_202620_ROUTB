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
