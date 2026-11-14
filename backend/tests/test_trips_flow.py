from datetime import timedelta
from typing import NamedTuple

from fastapi.testclient import TestClient
from unittest.mock import patch

from app.core.database import SessionLocal
from app.core.timezone import colombia_now, colombia_today
from app.main import app
from app.modules.auth.application.tokens import create_access_token
from app.modules.trips.infrastructure.models import Trip
from app.modules.users.infrastructure.models import User

client = TestClient(app)


def _create_driver(db_session, phone: str) -> tuple[User, str]:
    """Crea un conductor con vehículo completo y devuelve (user, token)."""
    driver = User(
        name="Carlos",
        last_name="Conductor",
        phone=phone,
        hashed_password="hash",
        role="driver",
        vehicle_model="Chevrolet Spark",
        vehicle_plate="XYZ-123",
        vehicle_color="Gris",
    )
    db_session.add(driver)
    db_session.commit()
    db_session.refresh(driver)
    token = create_access_token(driver.id, driver.role)
    return driver, token


class _TripScenario(NamedTuple):
    """Datos de un escenario con dos conductores y tres pasajeros."""

    driver_id: int
    driver_token: str
    other_driver_token: str
    user_ids: list[int]
    token_accepted: str
    token_pending: str
    token_external: str


_FAKE_ROUTE = {
    "distance_m": 2500,
    "duration_s": 300,
    "geometry": [[-75.55, 10.42], [-75.50, 10.40]],
    "degraded": False,
    "source": "osrm",
}


def _create_passenger(
    db_session, phone: str, *, last_name: str
) -> User:
    """Crea un pasajero."""
    passenger = User(
        name="Pasajero",
        last_name=last_name,
        phone=phone,
        hashed_password="hash",
        role="passenger",
    )
    db_session.add(passenger)
    db_session.commit()
    db_session.refresh(passenger)
    return passenger


def _create_trip_scenario(
    db_session, phones: tuple[str, str, str, str, str]
) -> _TripScenario:
    """Crea dos conductores con vehículo y tres pasajeros."""
    driver, driver_token = _create_driver(db_session, phones[0])
    other_driver, other_driver_token = _create_driver(
        db_session, phones[1]
    )
    accepted = _create_passenger(
        db_session, phones[2], last_name="Aceptado"
    )
    pending = _create_passenger(
        db_session, phones[3], last_name="Pendiente"
    )
    external = _create_passenger(
        db_session, phones[4], last_name="Externo"
    )
    return _TripScenario(
        driver_id=driver.id,
        driver_token=driver_token,
        other_driver_token=other_driver_token,
        user_ids=[
            driver.id,
            other_driver.id,
            accepted.id,
            pending.id,
            external.id,
        ],
        token_accepted=create_access_token(accepted.id, accepted.role),
        token_pending=create_access_token(pending.id, pending.role),
        token_external=create_access_token(external.id, external.role),
    )


def _create_route_trip(driver_token: str) -> int:
    """Crea un viaje from_campus hacia Manga; requiere el parche de OSRM activo."""
    resp = client.post(
        "/trips/",
        headers={"Authorization": f"Bearer {driver_token}"},
        json={
            "origin": "UTB Campus",
            "destination": "Barrio Manga",
            "total_seats": 4,
            "departure_time": "11:59 PM",
            "departure_date": str(colombia_today()),
            "direction": "from_campus",
            "driver_point": {
                "lat": 10.40,
                "lng": -75.50,
                "address_text": "Avenida El Lago, Manga",
            },
        },
    )
    assert resp.status_code == 201, resp.text
    return resp.json()["id"]


def test_flujo_completo_viajes_y_solicitudes():
    # 1. Crear usuario conductor y usuario pasajero en DB
    with SessionLocal() as db:
        driver = User(
            name="Carlos",
            last_name="Conductor",
            phone="3110000001",
            hashed_password="hash",
            role="driver",
            vehicle_model="Chevrolet Spark",
            vehicle_plate="XYZ-123",
            vehicle_color="Gris",
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

    # 2. Conductor crea un viaje (hora futura: evita expiración durante la suite)
    create_resp = client.post(
        "/trips/",
        headers={"Authorization": f"Bearer {driver_token}"},
        json={
            "origin": "Centro",
            "destination": "UTB",
            "total_seats": 3,
            "departure_time": "11:59 PM",
            "departure_date": str(colombia_today()),
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
    """Un conductor con vehículo puede publicar un viaje con dirección y driver_point."""
    with SessionLocal() as db:
        driver, token = _create_driver(db, "3110001001")
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
        driver, token = _create_driver(db, "3110001002")
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


def test_crear_viaje_sin_vehiculo_falla_409():
    """N2: el servidor rechaza publicar si falta el vehículo, aunque la app lo permita."""
    with SessionLocal() as db:
        driver = User(
            name="Sin",
            last_name="Vehículo",
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
            "departure_time": "11:59 PM",
            "departure_date": str(colombia_today()),
        },
    )

    assert resp.status_code == 409
    assert resp.json()["detail"] == "vehicle_required"

    # Un vehículo a medias (modelo y placa, sin color) tampoco habilita publicar.
    with SessionLocal() as db:
        incomplete = db.get(User, driver_id)
        incomplete.vehicle_model = "Chevrolet Spark"
        incomplete.vehicle_plate = "XYZ-123"
        db.commit()

    still_incomplete = client.post(
        "/trips/",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "origin": "Origen",
            "destination": "Destino",
            "total_seats": 2,
            "departure_time": "11:59 PM",
            "departure_date": str(colombia_today()),
        },
    )
    assert still_incomplete.status_code == 409
    assert still_incomplete.json()["detail"] == "vehicle_required"

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
            vehicle_model="Chevrolet Spark",
            vehicle_plate="XYZ-123",
            vehicle_color="Gris",
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


def test_crear_viaje_rechaza_fecha_fuera_de_hoy_manana():
    """La publicación solo admite hoy o mañana; una fecha lejana responde 422."""
    with SessionLocal() as db:
        driver, token = _create_driver(db, "3110001999")
        driver_id = driver.id

    try:
        payload = {
            "origin": "Centro",
            "destination": "UTB",
            "total_seats": 2,
            "departure_time": "11:59 PM",
        }

        payload["departure_date"] = str(colombia_today() + timedelta(days=2))
        rejected = client.post(
            "/trips/",
            headers={"Authorization": f"Bearer {token}"},
            json=payload,
        )
        assert rejected.status_code == 422
        assert "hoy o mañana" in rejected.json()["detail"]

        payload["departure_date"] = str(colombia_today() + timedelta(days=1))
        accepted = client.post(
            "/trips/",
            headers={"Authorization": f"Bearer {token}"},
            json=payload,
        )
        assert accepted.status_code == 201
    finally:
        from app.modules.trips.infrastructure.models import Trip

        with SessionLocal() as db:
            for trip in db.query(Trip).filter(Trip.driver_id == driver_id).all():
                db.delete(trip)
            user = db.get(User, driver_id)
            if user:
                db.delete(user)
            db.commit()


def test_listado_publico_oculta_viajes_que_ya_salieron():
    """Un viaje deja de ofertarse cuando su hora de salida ya pasó.

    El detalle sigue disponible para el historial y para las solicitudes que ya
    existían, pero el listado público no debe ofrecerlo.
    """
    with SessionLocal() as db:
        driver, token = _create_driver(db, "3110002100")
        driver_id = driver.id

    today = colombia_today()
    tomorrow = today + timedelta(days=1)
    headers = {"Authorization": f"Bearer {token}"}
    trip_ids: list[int] = []

    try:
        past_resp = client.post(
            "/trips/",
            headers=headers,
            json={
                "origin": "Centro",
                "destination": "UTB",
                "total_seats": 2,
                "departure_time": "7:00 AM",
                "departure_date": str(today),
            },
        )
        assert past_resp.status_code == 201, past_resp.text
        past_id = past_resp.json()["id"]
        trip_ids.append(past_id)

        future_resp = client.post(
            "/trips/",
            headers=headers,
            json={
                "origin": "Manga",
                "destination": "UTB",
                "total_seats": 2,
                "departure_time": "7:00 AM",
                "departure_date": str(tomorrow),
            },
        )
        assert future_resp.status_code == 201, future_resp.text
        future_id = future_resp.json()["id"]
        trip_ids.append(future_id)

        # Se fuerza la salida al pasado para que la prueba no dependa del reloj.
        with SessionLocal() as db:
            past_trip = db.get(Trip, past_id)
            past_trip.departure_at = colombia_now() - timedelta(minutes=1)
            db.commit()

        today_list = client.get(
            "/trips/", params={"departure_date": str(today)}
        )
        assert today_list.status_code == 200
        assert all(t["id"] != past_id for t in today_list.json())

        tomorrow_list = client.get(
            "/trips/", params={"departure_date": str(tomorrow)}
        )
        assert tomorrow_list.status_code == 200
        assert any(t["id"] == future_id for t in tomorrow_list.json())

        # El detalle sigue disponible para historial y solicitudes ya creadas.
        assert client.get(f"/trips/{past_id}").status_code == 200
    finally:
        with SessionLocal() as db:
            for trip_id in trip_ids:
                trip = db.get(Trip, trip_id)
                if trip is not None:
                    db.delete(trip)
            user = db.get(User, driver_id)
            if user is not None:
                db.delete(user)
            db.commit()


def test_my_trips_scope_filtra_activas_historial_y_todas():
    """`my-trips` con `scope`: activas por defecto, historial (canceladas o pasadas) y todas."""
    from app.modules.trips.infrastructure.models import Trip

    with SessionLocal() as db:
        driver, token = _create_driver(db, "3110002001")
        driver_id = driver.id

    headers = {"Authorization": f"Bearer {token}"}

    active_resp = client.post(
        "/trips/",
        headers=headers,
        json={
            "origin": "Manga",
            "destination": "UTB",
            "total_seats": 2,
            "departure_time": "11:59 PM",
        },
    )
    assert active_resp.status_code == 201
    active_id = active_resp.json()["id"]

    cancelled_resp = client.post(
        "/trips/",
        headers=headers,
        json={
            "origin": "Centro",
            "destination": "UTB",
            "total_seats": 2,
            "departure_time": "11:59 PM",
        },
    )
    assert cancelled_resp.status_code == 201
    cancelled_id = cancelled_resp.json()["id"]
    assert client.patch(f"/trips/{cancelled_id}/cancel", headers=headers).status_code == 200

    # Ruta pasada que no se puede publicar por API (solo admite hoy o mañana).
    with SessionLocal() as db:
        past = Trip(
            origin="Bocagrande",
            destination="UTB",
            total_seats=2,
            available_seats=2,
            driver_id=driver_id,
            departure_time="7:00 AM",
            departure_date=colombia_today() - timedelta(days=1),
        )
        db.add(past)
        db.commit()
        db.refresh(past)
        past_id = past.id

    try:
        default_ids = {
            t["id"] for t in client.get("/trips/my-trips", headers=headers).json()
        }
        assert active_id in default_ids
        assert cancelled_id not in default_ids

        history_ids = {
            t["id"]
            for t in client.get(
                "/trips/my-trips", headers=headers, params={"scope": "history"}
            ).json()
        }
        assert cancelled_id in history_ids
        assert past_id in history_ids
        assert active_id not in history_ids

        all_ids = {
            t["id"]
            for t in client.get(
                "/trips/my-trips", headers=headers, params={"scope": "all"}
            ).json()
        }
        assert {active_id, cancelled_id, past_id} <= all_ids

        invalid = client.get(
            "/trips/my-trips", headers=headers, params={"scope": "otro"}
        )
        assert invalid.status_code == 422
    finally:
        with SessionLocal() as db:
            for trip in db.query(Trip).filter(Trip.driver_id == driver_id).all():
                db.delete(trip)
            user = db.get(User, driver_id)
            if user:
                db.delete(user)
            db.commit()


def test_cancel_trip_cascades_to_requests_and_notifies():
    """Cancelar un viaje pasa sus solicitudes activas a `cancelled` y avisa a los aceptados."""
    from app.modules.notifications.infrastructure.models import DeviceToken
    from app.modules.requests.infrastructure.models import TripRequest
    from app.modules.trips.infrastructure.models import Trip

    with SessionLocal() as db:
        driver = User(
            name="Carlos",
            last_name="Cancela",
            phone="3110003001",
            hashed_password="hash",
            role="driver",
            vehicle_model="Chevrolet Spark",
            vehicle_plate="XYZ-123",
            vehicle_color="Gris",
        )
        accepted_a = User(
            name="Ana",
            last_name="Aceptada",
            phone="3110003002",
            hashed_password="hash",
            role="passenger",
        )
        accepted_b = User(
            name="Beto",
            last_name="Aceptado",
            phone="3110003003",
            hashed_password="hash",
            role="passenger",
        )
        pending = User(
            name="Celi",
            last_name="Pendiente",
            phone="3110003004",
            hashed_password="hash",
            role="passenger",
        )
        db.add_all([driver, accepted_a, accepted_b, pending])
        db.commit()
        db.refresh(driver)
        db.refresh(accepted_a)
        db.refresh(accepted_b)
        db.refresh(pending)

        user_ids = [driver.id, accepted_a.id, accepted_b.id, pending.id]
        passenger_ids = [accepted_a.id, accepted_b.id, pending.id]
        driver_token = create_access_token(driver.id, driver.role)
        passenger_tokens = {
            u.id: create_access_token(u.id, u.role)
            for u in (accepted_a, accepted_b, pending)
        }
        db.add_all(
            [
                DeviceToken(user_id=accepted_a.id, device_token="token-cascada-a", platform="android"),
                DeviceToken(user_id=accepted_b.id, device_token="token-cascada-b", platform="android"),
                DeviceToken(user_id=pending.id, device_token="token-cascada-p", platform="android"),
            ]
        )
        db.commit()

    trip_id = None
    try:
        create_resp = client.post(
            "/trips/",
            headers={"Authorization": f"Bearer {driver_token}"},
            json={
                "origin": "Centro",
                "destination": "UTB",
                "total_seats": 4,
                "departure_time": "11:59 PM",
                "departure_date": str(colombia_today()),
            },
        )
        assert create_resp.status_code == 201
        trip_id = create_resp.json()["id"]

        # 2 solicitudes aceptadas y 1 pendiente.
        request_ids = {}
        for passenger_id in passenger_ids:
            resp = client.post(
                f"/requests/trips/{trip_id}",
                headers={"Authorization": f"Bearer {passenger_tokens[passenger_id]}"},
            )
            assert resp.status_code == 201, resp.text
            request_ids[passenger_id] = resp.json()["id"]

        for passenger_id in passenger_ids[:2]:
            resp = client.patch(
                f"/requests/{request_ids[passenger_id]}/accept",
                headers={"Authorization": f"Bearer {driver_token}"},
            )
            assert resp.status_code == 200, resp.text

        with patch("app.modules.notifications.application.dispatch.send_push") as mock_push:
            cancel_resp = client.patch(
                f"/trips/{trip_id}/cancel",
                headers={"Authorization": f"Bearer {driver_token}"},
            )
        assert cancel_resp.status_code == 200
        assert cancel_resp.json()["status"] == "cancelled"

        # Todas las solicitudes asociadas quedan canceladas.
        with SessionLocal() as db:
            statuses = dict(
                db.query(TripRequest.id, TripRequest.status)
                .filter(TripRequest.trip_id == trip_id)
                .all()
            )
        assert statuses == {rid: "cancelled" for rid in request_ids.values()}

        # El pasajero lo ve reflejado en GET /requests/me.
        me_resp = client.get(
            "/requests/me",
            headers={"Authorization": f"Bearer {passenger_tokens[passenger_ids[0]]}"},
        )
        assert me_resp.status_code == 200
        mine = next(r for r in me_resp.json() if r["trip_id"] == trip_id)
        assert mine["status"] == "cancelled"
        assert mine["trip_status"] == "cancelled"

        # Se intentó despachar push solo a los pasajeros con solicitud aceptada.
        assert mock_push.call_count == 2
        notified = {token for call in mock_push.call_args_list for token in call.args[0]}
        assert notified == {"token-cascada-a", "token-cascada-b"}
        for call in mock_push.call_args_list:
            assert call.kwargs["title"] == "Viaje cancelado"
            assert "UTB" in call.kwargs["body"]
            assert call.kwargs["data"]["event"] == "trip_cancelled"
    finally:
        with SessionLocal() as db:
            db.query(DeviceToken).filter(
                DeviceToken.device_token.like("token-cascada-%")
            ).delete(synchronize_session=False)
            trip = db.get(Trip, trip_id)
            if trip:
                db.delete(trip)
            for uid in user_ids:
                user = db.get(User, uid)
                if user:
                    db.delete(user)
            db.commit()


def test_cancel_vs_accept_concurrent():
    """Carrera cancelar/aceptar: el viaje queda cancelado sin solicitudes activas."""
    import threading
    from concurrent.futures import ThreadPoolExecutor

    from app.modules.requests.infrastructure.models import TripRequest
    from app.modules.trips.infrastructure.models import Trip

    with SessionLocal() as db:
        driver = User(
            name="Raul",
            last_name="Racing",
            phone="3110003011",
            hashed_password="hash",
            role="driver",
            vehicle_model="Chevrolet Spark",
            vehicle_plate="XYZ-123",
            vehicle_color="Gris",
        )
        passenger = User(
            name="Pau",
            last_name="Racing",
            phone="3110003012",
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

    driver_headers = {"Authorization": f"Bearer {driver_token}"}
    intentos = 5
    try:
        for _ in range(intentos):
            create_resp = client.post(
                "/trips/",
                headers=driver_headers,
                json={
                    "origin": "Manga",
                    "destination": "UTB",
                    "total_seats": 2,
                    "departure_time": "11:59 PM",
                    "departure_date": str(colombia_today()),
                },
            )
            assert create_resp.status_code == 201
            trip_id = create_resp.json()["id"]

            req_resp = client.post(
                f"/requests/trips/{trip_id}",
                headers={"Authorization": f"Bearer {passenger_token}"},
            )
            assert req_resp.status_code == 201, req_resp.text
            request_id = req_resp.json()["id"]

            barrier = threading.Barrier(2, timeout=10)

            def _cancelar():
                barrier.wait()
                return client.patch(f"/trips/{trip_id}/cancel", headers=driver_headers)

            def _aceptar():
                barrier.wait()
                return client.patch(
                    f"/requests/{request_id}/accept", headers=driver_headers
                )

            with ThreadPoolExecutor(max_workers=2) as executor:
                cancel_future = executor.submit(_cancelar)
                accept_future = executor.submit(_aceptar)
                cancel_resp = cancel_future.result()
                accept_resp = accept_future.result()

            # La cancelación siempre prospera; la aceptación gana o pierde limpiamente.
            assert cancel_resp.status_code == 200, cancel_resp.text
            assert cancel_resp.json()["status"] == "cancelled"
            assert accept_resp.status_code in (200, 409), accept_resp.text

            # Sin estados incompatibles: viaje cancelado y solicitud cancelada.
            with SessionLocal() as db:
                assert db.get(Trip, trip_id).status == "cancelled"
                assert db.get(TripRequest, request_id).status == "cancelled"

            with SessionLocal() as db:
                trip = db.get(Trip, trip_id)
                if trip:
                    db.delete(trip)
                db.commit()
    finally:
        with SessionLocal() as db:
            for trip in db.query(Trip).filter(Trip.driver_id == driver_id).all():
                db.delete(trip)
            for uid in (passenger_id, driver_id):
                user = db.get(User, uid)
                if user:
                    db.delete(user)
            db.commit()


def test_my_trips_incluye_paradas_al_conductor_y_no_filtra_paradas_a_pasajeros():
    """El conductor dueño recibe solicitudes con paradas en my-trips; otros pasajeros no ven paradas ajenas."""
    from app.modules.trips.infrastructure.models import Trip

    with SessionLocal() as db:
        scenario = _create_trip_scenario(
            db,
            (
                "3110004001",
                "3110004002",
                "3110004003",
                "3110004004",
                "3110004005",
            ),
        )
    driver_id = scenario.driver_id
    driver_token = scenario.driver_token
    other_driver_token = scenario.other_driver_token
    user_ids = scenario.user_ids
    token_accepted = scenario.token_accepted
    token_pending = scenario.token_pending
    token_external = scenario.token_external

    try:
        with patch("app.shared.routing.service._call_osrm", return_value=_FAKE_ROUTE):
            trip_id = _create_route_trip(driver_token)

            req_accepted = client.post(
                f"/requests/trips/{trip_id}",
                headers={"Authorization": f"Bearer {token_accepted}"},
                json={
                    "seat_count": 1,
                    "stops": [
                        {
                            "seats": 1,
                            "place_type": "door",
                            "lat": 10.41,
                            "lng": -75.52,
                            "address_text": "Calle Privada Confirmada #10-20, Manga",
                        }
                    ],
                },
            )
            assert req_accepted.status_code == 201, req_accepted.text
            req_accepted_id = req_accepted.json()["id"]

            accept_resp = client.patch(
                f"/requests/{req_accepted_id}/accept",
                headers={"Authorization": f"Bearer {driver_token}"},
            )
            assert accept_resp.status_code == 200, accept_resp.text

            req_pending = client.post(
                f"/requests/trips/{trip_id}",
                headers={"Authorization": f"Bearer {token_pending}"},
                json={
                    "seat_count": 2,
                    "stops": [
                        {
                            "seats": 2,
                            "place_type": "meeting_point",
                            "lat": 10.42,
                            "lng": -75.53,
                            "address_text": "Barrio Pie de la Popa",
                        }
                    ],
                },
            )
            assert req_pending.status_code == 201, req_pending.text
            req_pending_id = req_pending.json()["id"]

        # 1. El conductor propietario recibe solicitudes y paradas directamente en GET /trips/my-trips
        my_trips_resp = client.get(
            "/trips/my-trips",
            headers={"Authorization": f"Bearer {driver_token}"},
        )
        assert my_trips_resp.status_code == 200
        my_trip = next(t for t in my_trips_resp.json() if t["id"] == trip_id)
        reqs_by_id = {r["id"]: r for r in my_trip["requests"]}
        assert set(reqs_by_id.keys()) == {req_accepted_id, req_pending_id}

        accepted_stops = reqs_by_id[req_accepted_id]["stops"]
        assert len(accepted_stops) == 1
        assert accepted_stops[0]["address_text"] == "Calle Privada Confirmada #10-20, Manga"
        assert accepted_stops[0]["seats"] == 1
        assert accepted_stops[0]["place_type"] == "door"
        assert "stop_geom" not in accepted_stops[0]

        pending_stops = reqs_by_id[req_pending_id]["stops"]
        assert len(pending_stops) == 1
        assert pending_stops[0]["address_text"] == "Barrio Pie de la Popa"
        assert pending_stops[0]["seats"] == 2
        assert pending_stops[0]["place_type"] == "meeting_point"
        assert pending_stops[0]["stop_seq"] is None
        assert pending_stops[0]["eta_estimated"] is None
        assert "stop_geom" not in pending_stops[0]

        # 2. Pasajero con solicitud pending, pasajero aceptado, pasajero ajeno, otro conductor y anónimo
        # no reciben paradas ni solicitudes de otras personas en GET /trips/ ni en GET /trips/{trip_id}.
        for token, expected_status in (
            (token_pending, "pending"),
            (token_accepted, "accepted"),
            (token_external, None),
            (other_driver_token, None),
            (None, None),
        ):
            headers = {"Authorization": f"Bearer {token}"} if token else {}

            list_resp = client.get("/trips/", headers=headers)
            assert list_resp.status_code == 200
            listed_trip = next(t for t in list_resp.json() if t["id"] == trip_id)
            assert listed_trip["requests"] == []
            assert listed_trip["my_request_status"] == expected_status

            detail_resp = client.get(f"/trips/{trip_id}", headers=headers)
            assert detail_resp.status_code == 200
            detail_trip = detail_resp.json()
            assert detail_trip["requests"] == []
            assert detail_trip["my_request_status"] == expected_status
    finally:
        with SessionLocal() as db:
            for trip in db.query(Trip).filter(Trip.driver_id == driver_id).all():
                db.delete(trip)
            for uid in user_ids:
                user = db.get(User, uid)
                if user:
                    db.delete(user)
            db.commit()


def test_telefono_del_pasajero_solo_se_expone_tras_aceptar():
    """El conductor no recibe el teléfono de solicitudes pendientes; sí el de las aceptadas (D3)."""
    from app.modules.trips.infrastructure.models import Trip

    with SessionLocal() as db:
        scenario = _create_trip_scenario(
            db,
            (
                "3110004101",
                "3110004102",
                "3110004103",
                "3110004104",
                "3110004105",
            ),
        )
    driver_id = scenario.driver_id
    driver_token = scenario.driver_token
    user_ids = scenario.user_ids
    accepted_phone = "3110004103"

    try:
        with patch("app.shared.routing.service._call_osrm", return_value=_FAKE_ROUTE):
            trip_id = _create_route_trip(driver_token)

            pending_resp = client.post(
                f"/requests/trips/{trip_id}",
                headers={"Authorization": f"Bearer {scenario.token_pending}"},
                json={
                    "seat_count": 1,
                    "stops": [
                        {
                            "seats": 1,
                            "place_type": "door",
                            "lat": 10.41,
                            "lng": -75.52,
                            "address_text": "Calle Pendiente #10-20",
                        }
                    ],
                },
            )
            assert pending_resp.status_code == 201, pending_resp.text
            pending_id = pending_resp.json()["id"]

            accepted_resp = client.post(
                f"/requests/trips/{trip_id}",
                headers={"Authorization": f"Bearer {scenario.token_accepted}"},
                json={
                    "seat_count": 1,
                    "stops": [
                        {
                            "seats": 1,
                            "place_type": "door",
                            "lat": 10.42,
                            "lng": -75.53,
                            "address_text": "Calle Aceptada #30-40",
                        }
                    ],
                },
            )
            assert accepted_resp.status_code == 201, accepted_resp.text
            accepted_id = accepted_resp.json()["id"]

            accept_resp = client.patch(
                f"/requests/{accepted_id}/accept",
                headers={"Authorization": f"Bearer {driver_token}"},
            )
            assert accept_resp.status_code == 200, accept_resp.text

        driver_headers = {"Authorization": f"Bearer {driver_token}"}

        # La aceptación devuelve el teléfono porque el cupo ya está confirmado.
        assert accept_resp.json()["passenger_phone"] == accepted_phone

        # my-trips: pendiente oculta, aceptada visible.
        my_trips_resp = client.get("/trips/my-trips", headers=driver_headers)
        assert my_trips_resp.status_code == 200
        my_trip = next(t for t in my_trips_resp.json() if t["id"] == trip_id)
        by_id = {r["id"]: r for r in my_trip["requests"]}
        assert by_id[pending_id]["passenger_phone"] is None
        assert by_id[accepted_id]["passenger_phone"] == accepted_phone

        # El detalle del viaje aplica la misma regla.
        detail_resp = client.get(f"/trips/{trip_id}", headers=driver_headers)
        assert detail_resp.status_code == 200
        by_id = {r["id"]: r for r in detail_resp.json()["requests"]}
        assert by_id[pending_id]["passenger_phone"] is None
        assert by_id[accepted_id]["passenger_phone"] == accepted_phone

        # El listado de solicitudes del conductor también filtra la pendiente.
        listed_resp = client.get(
            f"/requests/trips/{trip_id}", headers=driver_headers
        )
        assert listed_resp.status_code == 200
        by_id = {r["id"]: r for r in listed_resp.json()}
        assert by_id[pending_id]["passenger_phone"] is None
        assert by_id[accepted_id]["passenger_phone"] == accepted_phone
    finally:
        with SessionLocal() as db:
            for trip in db.query(Trip).filter(Trip.driver_id == driver_id).all():
                db.delete(trip)
            for uid in user_ids:
                user = db.get(User, uid)
                if user:
                    db.delete(user)
            db.commit()


def test_conductor_registra_vehiculo_valida_placa_colombiana_y_permisos():
    """El endpoint /users/me/vehicle valida placa colombiana, exige rol conductor y permite limpiar."""
    with SessionLocal() as db:
        driver = User(
            name="Mario",
            last_name="Conductor",
            phone="3110005001",
            hashed_password="hash",
            role="driver",
        )
        passenger = User(
            name="Elena",
            last_name="Pasajera",
            phone="3110005002",
            hashed_password="hash",
            role="passenger",
        )
        db.add_all([driver, passenger])
        db.commit()
        db.refresh(driver)
        db.refresh(passenger)
        user_ids = [driver.id, passenger.id]
        driver_token = create_access_token(driver.id, driver.role)
        passenger_token = create_access_token(passenger.id, passenger.role)

    driver_headers = {"Authorization": f"Bearer {driver_token}"}
    passenger_headers = {"Authorization": f"Bearer {passenger_token}"}

    try:
        # 1. Sin token: 401
        assert client.patch(
            "/users/me/vehicle",
            json={
                "vehicle_model": "Chevrolet Spark",
                "vehicle_plate": "XYZ-123",
                "vehicle_color": "Gris",
            },
        ).status_code == 401

        # 2. Pasajero no puede registrar vehículo: 403
        forbidden = client.patch(
            "/users/me/vehicle",
            headers=passenger_headers,
            json={
                "vehicle_model": "Chevrolet Spark",
                "vehicle_plate": "XYZ-123",
                "vehicle_color": "Gris",
            },
        )
        assert forbidden.status_code == 403

        # 3. Placas inválidas o datos incompletos devuelven 422
        for invalid_payload in (
            {
                "vehicle_model": "Chevrolet Spark",
                "vehicle_plate": "123-XYZ",
                "vehicle_color": "Gris",
            },
            {
                "vehicle_model": "Chevrolet Spark",
                "vehicle_plate": "AB-123",
                "vehicle_color": "Gris",
            },
            {
                "vehicle_model": "Chevrolet Spark",
                "vehicle_plate": "ABCD-123",
                "vehicle_color": "Gris",
            },
            {
                "vehicle_model": "Chevrolet Spark",
                "vehicle_plate": "ABC-12D",
                "vehicle_color": "Gris",
            },
            {
                "vehicle_model": "Chevrolet Spark",
                "vehicle_plate": "ABC-12",
                "vehicle_color": "Gris",
            },
            {
                "vehicle_model": "Chevrolet Spark",
                "vehicle_plate": None,
                "vehicle_color": "Gris",
            },
            {
                "vehicle_model": None,
                "vehicle_plate": "XYZ-123",
                "vehicle_color": "Gris",
            },
            {
                "vehicle_model": "Chevrolet Spark",
                "vehicle_plate": "XYZ-123",
                "vehicle_color": None,
            },
        ):
            bad_resp = client.patch(
                "/users/me/vehicle",
                headers=driver_headers,
                json=invalid_payload,
            )
            assert bad_resp.status_code == 422, f"{invalid_payload}: {bad_resp.text}"

        # 4. Registro válido normaliza la placa colombiana (ej. "xyz 123" -> "XYZ-123")
        ok_resp = client.patch(
            "/users/me/vehicle",
            headers=driver_headers,
            json={
                "vehicle_model": "  Chevrolet Spark  ",
                "vehicle_plate": "xyz 123",
                "vehicle_color": "  Gris  ",
            },
        )
        assert ok_resp.status_code == 200, ok_resp.text
        body = ok_resp.json()
        assert body["vehicle_model"] == "Chevrolet Spark"
        assert body["vehicle_plate"] == "XYZ-123"
        assert body["vehicle_color"] == "Gris"

        # 5. La app transporta automóviles: la placa de motocicleta (ABC-12D) se rechaza
        moto_resp = client.patch(
            "/users/me/vehicle",
            headers=driver_headers,
            json={
                "vehicle_model": "Yamaha FZ",
                "vehicle_plate": "abc12d",
                "vehicle_color": "Negra",
            },
        )
        assert moto_resp.status_code == 422, moto_resp.text

        # 6. GET /auth/me conserva el vehículo de automóvil y no el intento de moto
        me_resp = client.get("/auth/me", headers=driver_headers)
        assert me_resp.status_code == 200
        me_data = me_resp.json()
        assert me_data["vehicle_model"] == "Chevrolet Spark"
        assert me_data["vehicle_plate"] == "XYZ-123"
        assert me_data["vehicle_color"] == "Gris"

        # 7. Enviar campos vacíos/nulos limpia el vehículo
        clear_resp = client.patch(
            "/users/me/vehicle",
            headers=driver_headers,
            json={
                "vehicle_model": None,
                "vehicle_plate": None,
                "vehicle_color": None,
            },
        )
        assert clear_resp.status_code == 200
        assert clear_resp.json()["vehicle_model"] is None
        assert clear_resp.json()["vehicle_plate"] is None
        assert clear_resp.json()["vehicle_color"] is None
    finally:
        with SessionLocal() as db:
            for uid in user_ids:
                user = db.get(User, uid)
                if user:
                    db.delete(user)
            db.commit()


def test_vehicle_info_solo_se_expone_al_pasajero_con_solicitud_accepted():
    """vehicle_info solo es visible para el pasajero con solicitud accepted; nunca en listados públicos, sugerencias ni solicitudes pendientes."""
    from app.modules.trips.infrastructure.models import Trip

    with SessionLocal() as db:
        scenario = _create_trip_scenario(
            db,
            (
                "3110005011",
                "3110005012",
                "3110005013",
                "3110005014",
                "3110005015",
            ),
        )
    driver_id = scenario.driver_id
    driver_token = scenario.driver_token
    other_driver_token = scenario.other_driver_token
    user_ids = scenario.user_ids
    token_accepted = scenario.token_accepted
    token_pending = scenario.token_pending
    token_external = scenario.token_external

    try:
        # Conductor registra su vehículo
        veh_resp = client.patch(
            "/users/me/vehicle",
            headers={"Authorization": f"Bearer {driver_token}"},
            json={
                "vehicle_model": "Chevrolet Spark",
                "vehicle_plate": "xyz-123",
                "vehicle_color": "Gris",
            },
        )
        assert veh_resp.status_code == 200, veh_resp.text

        with patch("app.shared.routing.service._call_osrm", return_value=_FAKE_ROUTE):
            trip_id = _create_route_trip(driver_token)

            # Dos pasajeros solicitan cupo (ambos empiezan en pending)
            req_accepted_resp = client.post(
                f"/requests/trips/{trip_id}",
                headers={"Authorization": f"Bearer {token_accepted}"},
                json={
                    "seat_count": 1,
                    "stops": [
                        {
                            "seats": 1,
                            "place_type": "door",
                            "lat": 10.41,
                            "lng": -75.52,
                            "address_text": "Calle de la pasajera aceptada #10-20",
                        }
                    ],
                },
            )
            assert req_accepted_resp.status_code == 201, req_accepted_resp.text
            req_accepted_id = req_accepted_resp.json()["id"]

            req_pending_resp = client.post(
                f"/requests/trips/{trip_id}",
                headers={"Authorization": f"Bearer {token_pending}"},
                json={
                    "seat_count": 1,
                    "stops": [
                        {
                            "seats": 1,
                            "place_type": "door",
                            "lat": 10.42,
                            "lng": -75.53,
                            "address_text": "Calle del pasajero pendiente #30-40",
                        }
                    ],
                },
            )
            assert req_pending_resp.status_code == 201, req_pending_resp.text

            # Mientras la solicitud está en pending, GET /requests/me NO expone vehicle_info
            me_before = client.get(
                "/requests/me",
                headers={"Authorization": f"Bearer {token_accepted}"},
            )
            assert me_before.status_code == 200
            mine_pending = next(r for r in me_before.json() if r["trip_id"] == trip_id)
            assert mine_pending["status"] == "pending"
            assert mine_pending["vehicle_info"] is None

            # Conductor acepta solo a pass_accepted
            accept_resp = client.patch(
                f"/requests/{req_accepted_id}/accept",
                headers={"Authorization": f"Bearer {driver_token}"},
            )
            assert accept_resp.status_code == 200

        expected_vehicle = "Chevrolet Spark · Gris (XYZ-123)"

        # 1. Pasajero con solicitud accepted SÍ recibe vehicle_info en GET /requests/me y GET /trips/{trip_id}
        me_accepted = client.get(
            "/requests/me",
            headers={"Authorization": f"Bearer {token_accepted}"},
        )
        assert me_accepted.status_code == 200
        mine_accepted = next(r for r in me_accepted.json() if r["trip_id"] == trip_id)
        assert mine_accepted["status"] == "accepted"
        assert mine_accepted["vehicle_info"] == expected_vehicle

        detail_accepted = client.get(
            f"/trips/{trip_id}",
            headers={"Authorization": f"Bearer {token_accepted}"},
        )
        assert detail_accepted.status_code == 200
        assert detail_accepted.json()["vehicle_info"] == expected_vehicle

        # 2. Pasajero con solicitud pending NO recibe vehicle_info en GET /requests/me ni en GET /trips/{trip_id}
        me_still_pending = client.get(
            "/requests/me",
            headers={"Authorization": f"Bearer {token_pending}"},
        )
        assert me_still_pending.status_code == 200
        mine_still_pending = next(
            r for r in me_still_pending.json() if r["trip_id"] == trip_id
        )
        assert mine_still_pending["status"] == "pending"
        assert mine_still_pending["vehicle_info"] is None

        detail_pending = client.get(
            f"/trips/{trip_id}",
            headers={"Authorization": f"Bearer {token_pending}"},
        )
        assert detail_pending.status_code == 200
        assert detail_pending.json()["vehicle_info"] is None

        # 3. Listado público GET /trips/ NUNCA incluye vehicle_info (ni anónimo, ni ajeno, ni pendiente, ni aceptado)
        for token in (None, token_external, other_driver_token, token_pending, token_accepted):
            headers = {"Authorization": f"Bearer {token}"} if token else {}
            list_resp = client.get("/trips/", headers=headers)
            assert list_resp.status_code == 200
            listed_trip = next(t for t in list_resp.json() if t["id"] == trip_id)
            assert listed_trip["vehicle_info"] is None

        # 4. Detalle GET /trips/{trip_id} para anónimo, pasajero ajeno u otro conductor NO expone vehicle_info
        for token in (None, token_external, other_driver_token):
            headers = {"Authorization": f"Bearer {token}"} if token else {}
            detail_resp = client.get(f"/trips/{trip_id}", headers=headers)
            assert detail_resp.status_code == 200
            assert detail_resp.json()["vehicle_info"] is None

        # 5. Sugerencias GET /matching/suggestions NUNCA incluyen vehicle_info ni la placa
        sugg_resp = client.get(
            "/matching/suggestions",
            headers={"Authorization": f"Bearer {token_external}"},
            params={
                "direction": "from_campus",
                "points": "10.41,-75.52",
                "date": str(colombia_today()),
                "time": "11:59 PM",
            },
        )
        assert sugg_resp.status_code == 200
        for item in sugg_resp.json():
            assert "vehicle_info" not in item
            assert "XYZ-123" not in str(item)
    finally:
        with SessionLocal() as db:
            for trip in db.query(Trip).filter(Trip.driver_id == driver_id).all():
                db.delete(trip)
            for uid in user_ids:
                user = db.get(User, uid)
                if user:
                    db.delete(user)
            db.commit()


def test_ruta_calculada_se_expone_en_detalle_y_solicitudes_del_pasajero():
    """G22: la geometría guardada por el backend viaja al detalle y a «Mi viaje»."""
    from app.modules.trips.infrastructure.models import Trip

    with SessionLocal() as db:
        scenario = _create_trip_scenario(
            db,
            (
                "3110006011",
                "3110006012",
                "3110006013",
                "3110006014",
                "3110006015",
            ),
        )
    driver_id = scenario.driver_id
    driver_token = scenario.driver_token
    user_ids = scenario.user_ids
    token_accepted = scenario.token_accepted

    try:
        with patch("app.shared.routing.service._call_osrm", return_value=_FAKE_ROUTE):
            created = client.post(
                "/trips/",
                headers={"Authorization": f"Bearer {driver_token}"},
                json={
                    "origin": "UTB Campus",
                    "destination": "Barrio Manga",
                    "total_seats": 4,
                    "departure_time": "11:59 PM",
                    "departure_date": str(colombia_today()),
                    "direction": "from_campus",
                    "driver_point": {
                        "lat": 10.40,
                        "lng": -75.50,
                        "address_text": "Avenida El Lago, Manga",
                    },
                },
            )
            assert created.status_code == 201, created.text
            trip_id = created.json()["id"]
            assert created.json()["route_points"] == [
                {"lat": 10.42, "lng": -75.55},
                {"lat": 10.40, "lng": -75.50},
            ]

            requested = client.post(
                f"/requests/trips/{trip_id}",
                headers={"Authorization": f"Bearer {token_accepted}"},
                json={
                    "seat_count": 1,
                    "stops": [
                        {
                            "seats": 1,
                            "place_type": "door",
                            "lat": 10.40,
                            "lng": -75.50,
                            "address_text": "Avenida El Lago, Manga",
                        }
                    ],
                },
            )
            assert requested.status_code == 201, requested.text
            accepted = client.patch(
                f"/requests/{requested.json()['id']}/accept",
                headers={"Authorization": f"Bearer {driver_token}"},
            )
            assert accepted.status_code == 200, accepted.text

        detail = client.get(
            f"/trips/{trip_id}",
            headers={"Authorization": f"Bearer {token_accepted}"},
        )
        assert detail.status_code == 200
        detail_points = detail.json()["route_points"]
        assert len(detail_points) >= 2
        assert {"lat": 10.42, "lng": -75.55} in detail_points

        mine = client.get(
            "/requests/me",
            headers={"Authorization": f"Bearer {token_accepted}"},
        )
        assert mine.status_code == 200
        mine_trip = next(r for r in mine.json() if r["trip_id"] == trip_id)
        assert len(mine_trip["route_points"]) >= 2
        assert {"lat": 10.42, "lng": -75.55} in mine_trip["route_points"]
    finally:
        with SessionLocal() as db:
            for trip in db.query(Trip).filter(Trip.driver_id == driver_id).all():
                db.delete(trip)
            for uid in user_ids:
                user = db.get(User, uid)
                if user:
                    db.delete(user)
            db.commit()
