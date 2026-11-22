from uuid import uuid4

from fastapi.testclient import TestClient

from app.core.database import SessionLocal
from app.main import app
from app.modules.support.infrastructure.models import SupportReport

client = TestClient(app)


def test_report_auth_validation_and_idempotency():
    path = "/support/reports"
    payload = {
        "submission_id": str(uuid4()),
        "category": "trip",
        "description": "  El punto de encuentro no coincidía.  ",
    }
    assert client.post(path, json=payload).status_code == 401

    phone = "3099000081"
    password = "Test1234!"
    assert client.post(
        "/users/",
        json={
            "name": "Ana",
            "last_name": "Soporte",
            "phone": phone,
            "password": password,
            "role": "passenger",
        },
    ).status_code in (200, 201)
    login = client.post("/auth/login", json={"phone": phone, "password": password})
    assert login.status_code == 200
    headers = {"Authorization": f"Bearer {login.json()['access_token']}"}

    for invalid in ({"category": "invalid"}, {"description": " "}, {"description": "x" * 2001}):
        assert client.post(path, json=payload | invalid, headers=headers).status_code == 422

    first = client.post(path, json=payload, headers=headers)
    retry = client.post(path, json=payload, headers=headers)
    assert first.status_code == retry.status_code == 201
    assert first.json() == retry.json()
    conflict = client.post(path, json=payload | {"category": "driver"}, headers=headers)
    assert conflict.status_code == 409

    with SessionLocal() as db:
        report = db.get(SupportReport, first.json()["id"])
        assert report.description == payload["description"].strip()
        assert report.category == "trip"
        assert db.query(SupportReport).filter_by(submission_id=report.submission_id).count() == 1
