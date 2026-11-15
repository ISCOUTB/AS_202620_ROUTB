"""Eliminación de cuenta (G18): bloqueo con compromisos activos y borrado real."""

from fastapi.testclient import TestClient

from app.core.database import SessionLocal
from app.main import app
from app.modules.requests.infrastructure.models import TripRequest
from app.modules.trips.infrastructure.models import Trip
from app.modules.users.infrastructure.models import User
from tests.helpers import crear_usuario, crear_viaje, limpiar, parada

client = TestClient(app)


def _delete_me(token: str):
    return client.delete(
        "/users/me",
        headers={"Authorization": f"Bearer {token}"},
    )


def _borrar_viaje(trip_id: int) -> None:
    with SessionLocal() as db:
        db.query(TripRequest).filter(
            TripRequest.trip_id == trip_id
        ).delete(synchronize_session=False)
        trip = db.get(Trip, trip_id)
        if trip is not None:
            db.delete(trip)
        db.commit()


def test_conductor_no_puede_eliminar_cuenta_con_ruta_activa():
    driver_id, driver_token = crear_usuario("3500000001", role="driver")
    trip_id = crear_viaje(driver_token)

    try:
        blocked = _delete_me(driver_token)
        assert blocked.status_code == 409
        assert "Cancela tus rutas activas" in blocked.json()["detail"]

        with SessionLocal() as db:
            assert db.get(User, driver_id) is not None

        cancelled = client.patch(
            f"/trips/{trip_id}/cancel",
            headers={"Authorization": f"Bearer {driver_token}"},
        )
        assert cancelled.status_code == 200

        deleted = _delete_me(driver_token)
        assert deleted.status_code == 204

        # El token deja de servir en cuanto la cuenta desaparece.
        me = client.get(
            "/auth/me",
            headers={"Authorization": f"Bearer {driver_token}"},
        )
        assert me.status_code == 401

        with SessionLocal() as db:
            assert db.get(User, driver_id) is None
            # El viaje histórico se conserva, sin dueño.
            trip = db.get(Trip, trip_id)
            assert trip is not None
            assert trip.driver_id is None
    finally:
        _borrar_viaje(trip_id)
        limpiar(driver_id)


def test_pasajero_no_puede_eliminar_cuenta_con_solicitud_activa():
    driver_id, driver_token = crear_usuario("3500000002", role="driver")
    passenger_id, passenger_token = crear_usuario("3500000003")
    trip_id = crear_viaje(driver_token)

    try:
        requested = client.post(
            f"/requests/trips/{trip_id}",
            headers={"Authorization": f"Bearer {passenger_token}"},
            json={"seat_count": 1, "stops": [parada()]},
        )
        assert requested.status_code == 201
        request_id = requested.json()["id"]

        blocked = _delete_me(passenger_token)
        assert blocked.status_code == 409

        withdrawn = client.delete(
            f"/requests/{request_id}",
            headers={"Authorization": f"Bearer {passenger_token}"},
        )
        assert withdrawn.status_code == 204

        deleted = _delete_me(passenger_token)
        assert deleted.status_code == 204

        with SessionLocal() as db:
            assert db.get(User, passenger_id) is None
    finally:
        limpiar(passenger_id, driver_id)
