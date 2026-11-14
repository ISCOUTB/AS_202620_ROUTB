"""Validación y normalización de teléfonos en registro y login (TASK-03)."""

from uuid import uuid4

import pytest
from fastapi.testclient import TestClient

from app.core.database import SessionLocal
from app.main import app
from app.modules.users.infrastructure.models import User

client = TestClient(app)
PASSWORD = "PasswordSegura123!"


@pytest.fixture
def phone() -> str:
    """Un celular colombiano único por prueba, con limpieza al terminar."""
    value = f"3{uuid4().int % 1_000_000_000:09d}"
    yield value
    with SessionLocal() as db:
        db.query(User).filter(User.phone == value).delete(
            synchronize_session=False
        )
        db.commit()


def _payload(phone: str, **overrides: object) -> dict:
    data = {
        "name": "Ana",
        "last_name": "Ruiz",
        "phone": phone,
        "password": PASSWORD,
        "role": "passenger",
    }
    data.update(overrides)
    return data


def test_registro_guarda_telefono_canonico(phone: str) -> None:
    con_prefijo = f"+57 {phone[:3]}-{phone[3:6]}-{phone[6:]}"

    response = client.post("/users/", json=_payload(con_prefijo))

    assert response.status_code == 200, response.text
    assert response.json()["phone"] == phone
    with SessionLocal() as db:
        assert db.query(User).filter(User.phone == phone).count() == 1


def test_login_acepta_telefono_con_y_sin_prefijo(phone: str) -> None:
    assert client.post("/users/", json=_payload(phone)).status_code == 200

    for variant in (phone, f"+57 {phone}", f"57-{phone}"):
        response = client.post(
            "/auth/login",
            json={"phone": variant, "password": PASSWORD},
        )
        assert response.status_code == 200, f"{variant}: {response.text}"
        assert response.json()["user"]["phone"] == phone


@pytest.mark.parametrize(
    "invalid_phone",
    [
        "300123456",
        "30012345678",
        "300 123 456",
        "+57300123456",
        "57300123456",
        "1234567890",
        "30012345ab",
    ],
)
def test_registro_rechaza_telefonos_invalidos(invalid_phone: str) -> None:
    response = client.post("/users/", json=_payload(invalid_phone))

    assert response.status_code == 422, response.text


def test_login_rechaza_telefono_invalido() -> None:
    response = client.post(
        "/auth/login",
        json={"phone": "12345", "password": PASSWORD},
    )

    assert response.status_code == 422, response.text


def test_registro_rechaza_password_corta(phone: str) -> None:
    response = client.post(
        "/users/", json=_payload(phone, password="1234567")
    )

    assert response.status_code == 422, response.text


def test_registro_rechaza_nombres_demasiado_cortos(phone: str) -> None:
    response = client.post("/users/", json=_payload(phone, name="J"))

    assert response.status_code == 422, response.text
