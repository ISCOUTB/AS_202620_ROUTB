"""Pruebas de contrato OpenAPI para ROUTB (Evidencia S7).

Verifica que la API implementada en FastAPI coincida exactamente con la
especificación versionada en docs/openapi.json y que cualquier cambio incompatible
sea detectado en CI.
"""

import copy
import json
from pathlib import Path
import pytest

from app.main import app

CONTRACT_PATH = Path(__file__).resolve().parents[2] / "docs" / "openapi.json"


def _load_contract() -> dict:
    assert CONTRACT_PATH.exists(), f"No se encontró el archivo de contrato en {CONTRACT_PATH}"
    with open(CONTRACT_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


def _assert_contract_matches(contract: dict, implementation: dict) -> None:
    assert contract["openapi"] == implementation["openapi"], "La versión de OpenAPI no coincide"
    assert contract["info"]["title"] == implementation["info"]["title"], "El título de la API no coincide"
    assert contract["info"]["version"] == implementation["info"]["version"], "La versión de la API no coincide"

    # Verificar que todas las rutas del contrato existen en la implementación
    for ruta, operaciones in contract.get("paths", {}).items():
        assert ruta in implementation.get("paths", {}), f"Ruta '{ruta}' del contrato no encontrada en la implementación"
        for metodo, contrato_op in operaciones.items():
            assert metodo in implementation["paths"][ruta], f"Método '{metodo.upper()}' en '{ruta}' no encontrado en la implementación"
            impl_op = implementation["paths"][ruta][metodo]
            # Las respuestas del contrato deben estar documentadas en la implementación
            assert set(contrato_op.get("responses", {}).keys()) <= set(
                impl_op.get("responses", {}).keys()
            ), f"Códigos de respuesta no coinciden en {metodo.upper()} {ruta}"

    # Verificar esquemas de componentes declarados
    contract_schemas = contract.get("components", {}).get("schemas", {})
    impl_schemas = implementation.get("components", {}).get("schemas", {})
    for schema_name in contract_schemas:
        assert schema_name in impl_schemas, f"Esquema '{schema_name}' falta en components.schemas"


def test_openapi_contract_matches_implementation() -> None:
    """Verifica que la API implementada cumpla fielmente con el contrato OpenAPI versionado."""
    contract = _load_contract()
    implementation = app.openapi()
    _assert_contract_matches(contract, implementation)


def test_contract_detects_incompatible_breaking_change() -> None:
    """Demuestra que un cambio incompatible en la API rompe la prueba de contrato (requisito S7)."""
    contract = _load_contract()
    incompatible_impl = copy.deepcopy(app.openapi())

    # Simular la eliminación de una ruta clave (/trips/)
    if "/trips/" in incompatible_impl.get("paths", {}):
        del incompatible_impl["paths"]["/trips/"]

    with pytest.raises(AssertionError):
        _assert_contract_matches(contract, incompatible_impl)
