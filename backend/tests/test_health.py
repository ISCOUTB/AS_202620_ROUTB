"""Pruebas para el endpoint de salud y disponibilidad (Health Check) y observabilidad de ROUTB."""

from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_health_check_returns_200():
    """Verifica que el endpoint /health responda con status 200 y confirmación ok."""
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_root_returns_200():
    """Verifica que la raíz / responda con status 200 y mensaje de bienvenida."""
    response = client.get("/")
    assert response.status_code == 200
    assert "message" in response.json()
