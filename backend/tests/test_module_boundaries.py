"""Pruebas de frontera modular entre requests y trips (TASK-04 / Hallazgo E-4)."""

import ast
from pathlib import Path
import re

MODULES_DIR = Path(__file__).resolve().parents[1] / "app" / "modules"
REQUESTS_DIR = MODULES_DIR / "requests"
TRIPS_DIR = MODULES_DIR / "trips"

_DIRECT_TRIPS_MUTATION_SQL = re.compile(
    r"\b(?:UPDATE|INSERT\s+INTO|DELETE\s+FROM)\s+trips\b",
    re.IGNORECASE,
)


def _iter_python_files(base_dir: Path) -> list[Path]:
    return sorted(p for p in base_dir.rglob("*.py") if "__pycache__" not in p.parts)


def test_requests_does_not_execute_direct_mutating_sql_on_trips() -> None:
    """El módulo requests no debe mutar la tabla trips con SQL directo ni update/delete(Trip)."""
    violations: list[str] = []

    for py_file in _iter_python_files(REQUESTS_DIR):
        rel = py_file.relative_to(MODULES_DIR)
        source = py_file.read_text(encoding="utf-8")
        tree = ast.parse(source, filename=str(py_file))

        for node in ast.walk(tree):
            if isinstance(node, ast.Constant) and isinstance(node.value, str):
                if _DIRECT_TRIPS_MUTATION_SQL.search(node.value):
                    violations.append(
                        f"{rel}:{node.lineno} ejecuta SQL directo contra trips"
                    )
            elif isinstance(node, ast.Call):
                func_name = None
                if isinstance(node.func, ast.Name):
                    func_name = node.func.id
                elif isinstance(node.func, ast.Attribute):
                    func_name = node.func.attr

                if func_name in {"update", "insert", "delete"} and node.args:
                    first_arg = node.args[0]
                    if isinstance(first_arg, ast.Name) and first_arg.id == "Trip":
                        violations.append(
                            f"{rel}:{node.lineno} ejecuta {func_name}(Trip) directo"
                        )

    assert not violations, (
        "Violaciones de frontera modular detectadas en requests -> trips:\n"
        + "\n".join(violations)
    )


def test_order_stops_delegates_route_update_to_trips_application() -> None:
    """order_stops debe delegar la actualización de ruta a set_trip_route de trips.application."""
    from app.modules.trips import application as trips_app

    assert hasattr(trips_app, "set_trip_route"), (
        "app.modules.trips.application debe exportar set_trip_route"
    )

    order_stops_path = REQUESTS_DIR / "application" / "order_stops.py"
    source = order_stops_path.read_text(encoding="utf-8")
    tree = ast.parse(source, filename=str(order_stops_path))

    imported_from_trips = any(
        isinstance(node, ast.ImportFrom)
        and node.module in {
            "app.modules.trips.application",
            "app.modules.trips.application.update_trip_route",
        }
        and any(alias.name == "set_trip_route" for alias in node.names)
        for node in ast.walk(tree)
    )
    called_set_trip_route = any(
        isinstance(node, ast.Call)
        and isinstance(node.func, ast.Name)
        and node.func.id == "set_trip_route"
        for node in ast.walk(tree)
    )

    assert imported_from_trips, (
        "order_stops.py debe importar set_trip_route desde app.modules.trips.application"
    )
    assert called_set_trip_route, (
        "order_stops.py debe invocar set_trip_route para actualizar la ruta del viaje"
    )


def test_trips_does_not_import_requests_schemas() -> None:
    """El módulo trips no debe importar schemas de requests."""
    violations: list[str] = []

    for py_file in _iter_python_files(TRIPS_DIR):
        rel = py_file.relative_to(MODULES_DIR)
        source = py_file.read_text(encoding="utf-8")
        tree = ast.parse(source, filename=str(py_file))

        for node in ast.walk(tree):
            if isinstance(node, ast.ImportFrom) and node.module:
                if node.module.startswith("app.modules.requests") and "schemas" in node.module:
                    violations.append(f"{rel}:{node.lineno} importa {node.module}")
            elif isinstance(node, ast.Import):
                for alias in node.names:
                    if alias.name.startswith("app.modules.requests") and "schemas" in alias.name:
                        violations.append(f"{rel}:{rel} importa {alias.name}")

    assert not violations, (
        "El módulo trips importa schemas de requests:\n" + "\n".join(violations)
    )


def test_set_trip_route_preserves_caller_transaction() -> None:
    """set_trip_route debe usar la sesión activa sin hacer commit propio."""
    from unittest.mock import MagicMock

    from app.modules.trips.application import set_trip_route

    fake_db = MagicMock()
    set_trip_route(
        fake_db,
        trip_id=42,
        line_geojson='{"type": "LineString", "coordinates": [[-75.5, 10.4], [-75.51, 10.41]]}',
        distance_m=1500,
        duration_s=300,
        source="osrm",
    )

    assert fake_db.execute.call_count == 1
    assert fake_db.commit.call_count == 0

