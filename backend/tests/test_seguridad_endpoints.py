"""Endpoints endurecidos del Aspecto 3 (autenticación y protección de datos).

Verifica que las rutas que exponían o modificaban datos personales sin validar
identidad ya no sean accesibles de forma anónima:

- ``GET /users/`` se retiró por completo (devolvía ``hashed_password``).
- ``POST /trips/`` exige token.
- ``PATCH /trips/{trip_id}/cancel`` exige token y propiedad.
- ``POST /trips/{trip_id}/reservations`` (reserva anónima legada) se retiró.
"""

from fastapi.testclient import TestClient

from app.core.database import SessionLocal
from app.core.timezone import colombia_today
from app.main import app
from app.modules.auth.application.tokens import create_access_token
from app.modules.users.infrastructure.models import User

from tests.helpers import limpiar

client = TestClient(app)


def _crear_usuario(telefono: str, role: str = "driver") -> tuple[int, str]:
    """Crea un usuario directo en BD y devuelve ``(id, token)``."""
    with SessionLocal() as db:
        user = User(
            name="Seg",
            last_name="Urity",
            phone=telefono,
            hashed_password="hash",
            role=role,
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        return user.id, create_access_token(user.id, user.role)


def _payload_viaje() -> dict:
    return {
        "origin": "Centro",
        "destination": "UTB",
        "total_seats": 2,
        "departure_time": "11:59 PM",
        "departure_date": str(colombia_today()),
    }


def test_get_users_retirado():
    """La ruta sigue viva por el registro, pero el GET ya no existe."""
    assert client.get("/users/").status_code == 405


def test_crear_viaje_anonimo_rechazado():
    """Sin token no se puede publicar un viaje."""
    assert client.post("/trips/", json=_payload_viaje()).status_code == 401


def test_reserva_anonima_legada_retirada():
    """El endpoint de reserva directa ya no existe."""
    assert client.post("/trips/1/reservations").status_code == 404


def test_cancelar_viaje_exige_propiedad():
    """Sin token no se cancela; con otro conductor tampoco."""
    driver_id, driver_token = _crear_usuario("3190000010", "driver")
    other_id, other_token = _crear_usuario("3190000011", "driver")
    try:
        creado = client.post(
            "/trips/",
            headers={"Authorization": f"Bearer {driver_token}"},
            json=_payload_viaje(),
        )
        assert creado.status_code == 201, creado.text
        trip_id = creado.json()["id"]

        # Anónimo: rechazado por falta de credenciales.
        assert client.patch(f"/trips/{trip_id}/cancel").status_code == 401

        # Otro conductor: rechazado por falta de propiedad.
        assert (
            client.patch(
                f"/trips/{trip_id}/cancel",
                headers={"Authorization": f"Bearer {other_token}"},
            ).status_code
            == 404
        )

        # El dueño sí puede cancelarlo.
        assert (
            client.patch(
                f"/trips/{trip_id}/cancel",
                headers={"Authorization": f"Bearer {driver_token}"},
            ).status_code
            == 200
        )
    finally:
        limpiar(driver_id, other_id)
