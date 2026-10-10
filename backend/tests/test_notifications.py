"""Pruebas del módulo de notificaciones: registro y eliminación de tokens FCM."""

import pytest
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def _register_user_and_login(phone: str, password: str = "Test1234!") -> str:
    """Registra un usuario y devuelve su JWT."""
    client.post(
        "/users/",
        json={
            "name": "Tester",
            "last_name": "Notif",
            "phone": phone,
            "password": password,
            "role": "passenger",
        },
    )
    resp = client.post("/auth/login", json={"phone": phone, "password": password})
    assert resp.status_code == 200, f"Login fallido: {resp.text}"
    return resp.json()["access_token"]


class TestDeviceToken:
    def test_register_token_requiere_auth(self):
        resp = client.put(
            "/notifications/device-token",
            json={"device_token": "tok_abc", "platform": "android"},
        )
        assert resp.status_code == 403

    def test_register_token_exitoso(self):
        token = _register_user_and_login("3099000001")
        resp = client.put(
            "/notifications/device-token",
            json={"device_token": "fcm_test_token_001", "platform": "android"},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["device_token"] == "fcm_test_token_001"
        assert data["platform"] == "android"
        assert "id" in data

    def test_register_token_idempotente(self):
        """Registrar el mismo token dos veces no falla."""
        token = _register_user_and_login("3099000002")
        payload = {"device_token": "fcm_test_token_002", "platform": "ios"}
        headers = {"Authorization": f"Bearer {token}"}

        r1 = client.put("/notifications/device-token", json=payload, headers=headers)
        r2 = client.put("/notifications/device-token", json=payload, headers=headers)
        assert r1.status_code == 200
        assert r2.status_code == 200
        assert r1.json()["id"] == r2.json()["id"]

    def test_eliminar_token_no_existente_404(self):
        token = _register_user_and_login("3099000003")
        resp = client.delete(
            "/notifications/device-token/token_que_no_existe",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 404

    def test_eliminar_token_exitoso(self):
        token = _register_user_and_login("3099000004")
        headers = {"Authorization": f"Bearer {token}"}

        client.put(
            "/notifications/device-token",
            json={"device_token": "fcm_test_token_004", "platform": "android"},
            headers=headers,
        )

        resp = client.delete(
            "/notifications/device-token/fcm_test_token_004",
            headers=headers,
        )
        assert resp.status_code == 204

    def test_platform_invalida_422(self):
        token = _register_user_and_login("3099000005")
        resp = client.put(
            "/notifications/device-token",
            json={"device_token": "fcm_abc", "platform": "windows"},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 422
