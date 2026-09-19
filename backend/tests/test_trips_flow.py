from fastapi.testclient import TestClient

from app.core.database import SessionLocal
from app.main import app
from app.modules.auth.infrastructure.security import create_access_token
from app.modules.users.infrastructure.models import User

client = TestClient(app)


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
        driver_token = create_access_token(driver)
        passenger_token = create_access_token(passenger)

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
