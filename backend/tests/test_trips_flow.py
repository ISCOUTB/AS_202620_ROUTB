from fastapi.testclient import TestClient
from unittest.mock import patch

from app.core.database import SessionLocal
from app.main import app
from app.modules.auth.application.tokens import create_access_token
from app.modules.users.infrastructure.models import User

client = TestClient(app)


def _create_driver_with_consent(db_session, phone: str) -> tuple[User, str]:
    """Crea un conductor con consentimiento de ubicación y devuelve (user, token)."""
    from datetime import datetime
    from zoneinfo import ZoneInfo

    driver = User(
        name="Carlos",
        last_name="Conductor",
        phone=phone,
        hashed_password="hash",
        role="driver",
        location_consent_at=datetime.now(ZoneInfo("America/Bogota")),
    )
    db_session.add(driver)
    db_session.commit()
    db_session.refresh(driver)
    token = create_access_token(driver.id, driver.role)
    return driver, token


def test_flujo_completo_viajes_y_solicitudes():
    # 1. Crear usuario conductor y usuario pasajero en DB
    with SessionLocal() as db:
        driver = User(
            name="Carlos",
            last_name="Conductor",
            phone="3110000001",
            hashed_password="hash",
            role="driver",
        )
        passenger = User(
            name="Laura",
            last_name="Pasajera",
            phone="3110000002",
            hashed_password="hash",
            role="passenger",
        )
        db.add_all([driver, passenger])
        db.commit()
        db.refresh(driver)
        db.refresh(passenger)

        driver_id = driver.id
        passenger_id = passenger.id
        driver_token = create_access_token(driver.id, driver.role)
        passenger_token = create_access_token(passenger.id, passenger.role)

    # 2. Conductor crea un viaje
    create_resp = client.post(
        "/trips/",
        headers={"Authorization": f"Bearer {driver_token}"},
        json={
            "origin": "Centro",
            "destination": "UTB",
            "total_seats": 3,
            "departure_time": "7:00 AM",
        },
    )
    assert create_resp.status_code == 201
    trip = create_resp.json()
    assert trip["origin"] == "Centro"
    assert trip["destination"] == "UTB"
    assert trip["total_seats"] == 3
    assert trip["available_seats"] == 3
    assert trip["driver_id"] == driver_id
    trip_id = trip["id"]

    # 3. Pasajero consulta viajes activos
    list_resp = client.get("/trips/")
    assert list_resp.status_code == 200
    trips = list_resp.json()
    assert any(t["id"] == trip_id for t in trips)

    # 4. Conductor consulta sus propios viajes
    my_trips_resp = client.get(
        "/trips/my-trips",
        headers={"Authorization": f"Bearer {driver_token}"},
    )
    assert my_trips_resp.status_code == 200
    assert any(t["id"] == trip_id for t in my_trips_resp.json())

    # 5. Pasajero solicita cupo
    req_resp = client.post(
        f"/requests/trips/{trip_id}",
        headers={"Authorization": f"Bearer {passenger_token}"},
    )
    assert req_resp.status_code == 201
    request_data = req_resp.json()
    assert request_data["trip_id"] == trip_id
    assert request_data["passenger_id"] == passenger_id
    assert request_data["status"] == "pending"
    request_id = request_data["id"]

    # 6. Conductor consulta solicitudes de su viaje
    trip_reqs_resp = client.get(
        f"/requests/trips/{trip_id}",
        headers={"Authorization": f"Bearer {driver_token}"},
    )
    assert trip_reqs_resp.status_code == 200
    assert any(r["id"] == request_id for r in trip_reqs_resp.json())

    # 7. Conductor acepta la solicitud
    accept_resp = client.patch(
        f"/requests/{request_id}/accept",
        headers={"Authorization": f"Bearer {driver_token}"},
    )
    assert accept_resp.status_code == 200
    assert accept_resp.json()["status"] == "accepted"

    # Verificar que los cupos disponibles disminuyeron a 2
    trip_check = client.get(f"/trips/{trip_id}").json()
    assert trip_check["available_seats"] == 2

    # 8. Conductor cancela la ruta
    cancel_resp = client.patch(
        f"/trips/{trip_id}/cancel",
        headers={"Authorization": f"Bearer {driver_token}"},
    )
    assert cancel_resp.status_code == 200
    assert cancel_resp.json()["status"] == "cancelled"

    # Limpieza
    with SessionLocal() as db:
        u1 = db.get(User, driver_id)
        u2 = db.get(User, passenger_id)
        if u1:
            db.delete(u1)
        if u2:
            db.delete(u2)
        db.commit()


def test_crear_viaje_con_direction_to_campus():
    """Un conductor con consentimiento puede publicar un viaje con dirección y driver_point."""
    with SessionLocal() as db:
        driver, token = _create_driver_with_consent(db, "3110001001")
        driver_id = driver.id

    _fake_route = {
        "distance_m": 3000,
        "duration_s": 400,
        "geometry": [[-75.55, 10.42], [-75.55, 10.42]],
        "degraded": False,
        "source": "osrm",
    }

    with patch("app.shared.routing.service._call_osrm", return_value=_fake_route):
        resp = client.post(
            "/trips/",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "origin": "Barrio La Esperanza",
                "destination": "UTB Campus",
                "total_seats": 2,
                "departure_time": "7:30 AM",
                "direction": "to_campus",
                "driver_point": {
                    "lat": 10.42,
                    "lng": -75.55,
                    "address_text": "Calle 30 # 15-20, Cartagena",
                },
            },
        )

    assert resp.status_code == 201
    data = resp.json()
    assert data["status"] == "active"

    # Limpieza
    with SessionLocal() as db:
        u = db.get(User, driver_id)
        if u:
            db.delete(u)
        db.commit()


def test_crear_viaje_con_direction_from_campus():
    """Viaje en sentido from_campus: campus es el origen, el punto del conductor es el destino."""
    with SessionLocal() as db:
        driver, token = _create_driver_with_consent(db, "3110001002")
        driver_id = driver.id

    _fake_route = {
        "distance_m": 2500,
        "duration_s": 300,
        "geometry": [[-75.55, 10.42], [-75.50, 10.40]],
        "degraded": False,
        "source": "osrm",
    }

    with patch("app.shared.routing.service._call_osrm", return_value=_fake_route):
        resp = client.post(
            "/trips/",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "origin": "UTB Campus",
                "destination": "Barrio Manga",
                "total_seats": 3,
                "departure_time": "6:00 PM",
                "direction": "from_campus",
                "driver_point": {
                    "lat": 10.40,
                    "lng": -75.50,
                    "address_text": "Avenida El Lago, Manga",
                },
            },
        )

    assert resp.status_code == 201
    assert resp.json()["status"] == "active"

    # Limpieza
    with SessionLocal() as db:
        u = db.get(User, driver_id)
        if u:
            db.delete(u)
        db.commit()


def test_crear_viaje_sin_consentimiento_falla_403():
    """Un conductor sin location_consent_at recibe 403 al publicar con driver_point."""
    with SessionLocal() as db:
        driver = User(
            name="Sin",
            last_name="Consentimiento",
            phone="3110001003",
            hashed_password="hash",
            role="driver",
        )
        db.add(driver)
        db.commit()
        db.refresh(driver)
        driver_id = driver.id
        token = create_access_token(driver.id, driver.role)

    resp = client.post(
        "/trips/",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "origin": "Origen",
            "destination": "Destino",
            "total_seats": 2,
            "direction": "to_campus",
            "driver_point": {
                "lat": 10.42,
                "lng": -75.55,
                "address_text": "Calle Test",
            },
        },
    )

    assert resp.status_code == 403
    assert "location_consent_required" in resp.json()["detail"]

    # Limpieza
    with SessionLocal() as db:
        u = db.get(User, driver_id)
        if u:
            db.delete(u)
        db.commit()


def test_viaje_legado_sin_coordenadas_sigue_funcionando():
    """Los viajes sin direction ni driver_point se crean igual que antes."""
    with SessionLocal() as db:
        driver = User(
            name="Legado",
            last_name="Driver",
            phone="3110001004",
            hashed_password="hash",
            role="driver",
        )
        db.add(driver)
        db.commit()
        db.refresh(driver)
        driver_id = driver.id
        token = create_access_token(driver.id, driver.role)

    resp = client.post(
        "/trips/",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "origin": "Barrio Histórico",
            "destination": "UTB",
            "total_seats": 4,
        },
    )

    assert resp.status_code == 201
    data = resp.json()
    assert data["origin"] == "Barrio Histórico"

    # Limpieza
    with SessionLocal() as db:
        u = db.get(User, driver_id)
        if u:
            db.delete(u)
        db.commit()
