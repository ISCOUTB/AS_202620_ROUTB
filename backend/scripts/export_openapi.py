"""Script para exportar el contrato OpenAPI de ROUTB a docs/openapi.json."""

import json
import os
import sys
from pathlib import Path

# Configurar variables de entorno seguras para exportación sin requerir DB externa
os.environ.setdefault("TESTING", "1")
os.environ.setdefault("DATABASE_URL_TEST", "sqlite:///temp_export.db")
os.environ.setdefault("JWT_SECRET_KEY", "export-openapi-secret-key")

BACKEND_DIR = Path(__file__).resolve().parents[1]
WORKSPACE_ROOT = BACKEND_DIR.parent

sys.path.insert(0, str(BACKEND_DIR))

from app.main import app  # noqa: E402


def export_openapi() -> None:
    target_path = WORKSPACE_ROOT / "docs" / "openapi.json"
    target_path.parent.mkdir(parents=True, exist_ok=True)

    schema = app.openapi()

    with open(target_path, "w", encoding="utf-8") as f:
        json.dump(schema, f, indent=2, ensure_ascii=False)
        f.write("\n")

    print(f"Contrato OpenAPI exportado exitosamente en: {target_path}")
    print(f"Rutas exportadas: {len(schema.get('paths', {}))}")


if __name__ == "__main__":
    export_openapi()
