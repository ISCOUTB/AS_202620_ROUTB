from importlib import import_module

from alembic.migration import MigrationContext
from alembic.operations import Operations
from sqlalchemy import text

from app.core.database import SessionLocal, engine
from app.core.timezone import colombia_today
from app.modules.users.infrastructure.models import User
from tests.helpers import client, crear_usuario, crear_viaje, limpiar, parada


def test_activacion_sin_cambiar_identidad_jwt_o_reservas():
    uid, token = crear_usuario("3198010101")
    other, other_token = crear_usuario("3198010102", role="driver")
    auth = {"Authorization": f"Bearer {token}"}
    vehicle = {"vehicle_model": "Spark", "vehicle_color": "Azul", "vehicle_plate": "abc 123"}
    try:
        other_trip = crear_viaje(other_token)
        booking = client.post(f"/requests/trips/{other_trip}", headers=auth,
                              json={"seat_count": 1, "stops": [parada()]})
        assert booking.is_success, booking.text
        assert client.patch("/users/me/mode", headers=auth, json={"mode": "driver"}).status_code == 403
        assert client.patch("/users/me/mode", headers=auth, json={"mode": "admin"}).status_code == 422
        assert client.put("/users/me/driver", json=vehicle).status_code == 401
        assert client.put("/users/me/driver", headers=auth, json={}).status_code == 422
        assert not client.get("/auth/me", headers=auth).json()["driver_enabled"]
        result = client.put("/users/me/driver", headers=auth, json=vehicle)
        assert result.status_code == 200, result.text
        assert result.json()["id"] == uid
        assert result.json()["vehicle_plate"] == "ABC-123"
        assert result.json()["active_mode"] == "driver"
        own_trip = crear_viaje(token)
        assert client.patch("/users/me/mode", headers=auth, json={"mode": "passenger"}).is_success
        saved = client.get("/auth/me", headers=auth).json()
        assert saved["active_mode"] == "passenger" and saved["driver_enabled"]
        assert saved["role"] == "driver"  # compatibilidad de lectura
        with SessionLocal() as db:
            assert db.get(User, uid).role == "passenger"
        own_booking = client.post(f"/requests/trips/{own_trip}", headers=auth,
                                  json={"seat_count": 1, "stops": [parada()]})
        assert own_booking.status_code == 400
        assert any(r["id"] == booking.json()["id"] for r in client.get("/requests/me", headers=auth).json())
        assert client.patch("/users/me/mode", headers=auth, json={"mode": "driver"}).is_success
        assert own_trip in [t["id"] for t in client.get("/trips/my-trips", headers=auth).json()]
    finally:
        limpiar(uid, other)


def test_migracion_preserva_identidades_y_modo_historico():
    migration = import_module("migrations.versions.016_user_travel_modes")
    with engine.begin() as conn:
        conn.execute(text("CREATE TEMP TABLE users (id integer, role text, vehicle_plate text) ON COMMIT DROP"))
        conn.execute(text("INSERT INTO users VALUES (7, 'driver', 'ABC-123'), (9, 'passenger', NULL)"))
        with Operations.context(MigrationContext.configure(conn)):
            migration.upgrade()
        rows = conn.execute(text("SELECT id, role, vehicle_plate, preferred_mode, driver_activated_at FROM pg_temp.users ORDER BY id")).all()
        assert rows == [(7, "driver", "ABC-123", None, None), (9, "passenger", None, None, None)]

def test_vehiculo_y_modo_no_otorgan_privilegios_por_si_solos():
    uid, token = crear_usuario("3198010103")
    auth = {"Authorization": f"Bearer {token}"}
    try:
        with SessionLocal() as db:
            user = db.get(User, uid)
            user.vehicle_model, user.vehicle_plate, user.vehicle_color = "Spark", "ABC-123", "Gris"
            db.commit()
        response = client.post("/trips/", headers=auth, json={
            "origin": "Manga", "destination": "UTB", "total_seats": 2,
            "departure_date": str(colombia_today()), "departure_time": "11:59 PM",
        })
        assert response.status_code == 409, response.text
        assert not client.get("/auth/me", headers=auth).json()["driver_enabled"]
    finally:
        limpiar(uid)


def test_modalidad_conserva_rol_administrativo_preexistente():
    uid, token = crear_usuario("3198010104", role="admin")
    auth = {"Authorization": f"Bearer {token}"}
    try:
        before = client.get("/auth/me", headers=auth).json()
        assert before["role"] == "admin" and not before["driver_enabled"]
        activated = client.put("/users/me/driver", headers=auth, json={
            "vehicle_model": "Spark", "vehicle_plate": "ABC-123", "vehicle_color": "Azul",
        })
        assert activated.json()["role"] == "admin"
        result = client.patch("/users/me/mode", headers=auth, json={"mode": "passenger"})
        assert result.json()["role"] == "admin" and result.json()["driver_enabled"]
        with SessionLocal() as db:
            assert db.get(User, uid).role == "admin"
    finally:
        limpiar(uid)
