from fastapi.testclient import TestClient

from app.core.database import SessionLocal
from app.main import app
from app.modules.auth.application.tokens import create_access_token
from app.modules.requests.infrastructure.models import TripRequest
from app.modules.trips.infrastructure.models import Trip
from app.modules.users.infrastructure.models import User

client = TestClient(app)


def _crear_conductor(telefono: str):
    with SessionLocal() as db:
        user = User(
            name="Carla",
            last_name="Conductora",
            phone=telefono,
            hashed_password="hash",
            role="driver",
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        return user.id, create_access_token(user.id, user.role)


def _crear_pasajero(telefono: str):
    with SessionLocal() as db:
        user = User(
            name="Paco",
            last_name="Pasajero",
            phone=telefono,
            hashed_password="hash",
            role="passenger",
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        return user.id, create_access_token(user.id, user.role)


def _limpiar(*user_ids: int):
    """Borra usuarios y todo lo suyo.

    No basta con borrar el usuario: en SQLite las claves foraneas no aplican
    cascada, asi que quedarian `trip_requests` huerfanas. Como SQLite tambien
    recicla los ids, el siguiente test que cree un pasajero se encontraria con
    las solicitudes del anterior.
    """
    with SessionLocal() as db:
        for user_id in user_ids:
            db.query(TripRequest).filter(
                TripRequest.passenger_id == user_id
            ).delete(synchronize_session=False)
            for trip in (
                db.query(Trip).filter(Trip.driver_id == user_id).all()
            ):
                db.query(TripRequest).filter(
                    TripRequest.trip_id == trip.id
                ).delete(synchronize_session=False)
                db.delete(trip)
            user = db.get(User, user_id)
            if user:
                db.delete(user)
        db.commit()


def _viaje(token_conductor: str, total_seats: int = 1) -> int:
    resp = client.post(
        "/trips/",
        headers={"Authorization": f"Bearer {token_conductor}"},
        json={
            "origin": "Centro",
            "destination": "UTB",
            "total_seats": total_seats,
            "departure_time": "7:00 AM",
        },
    )
    assert resp.status_code == 201
    return resp.json()["id"]


def test_mis_solicitudes_incluye_el_viaje_que_ya_no_tiene_cupos():
    """El caso que `GET /trips/` no cubre: ocupar el ultimo cupo.

    El listado publico filtra `available_seats > 0`, asi que en cuanto el
    pasajero toma el ultimo sitio su viaje desaparece de ahi. `/requests/me`
    tiene que seguir devolvienselo.
    """
    driver_id, driver_token = _crear_conductor("3120000001")
    passenger_id, passenger_token = _crear_pasajero("3120000002")

    try:
        trip_id = _viaje(driver_token, total_seats=1)

        # Mientras hay cupo libre, el viaje sale en el listado publico.
        publico = client.get("/trips/").json()
        assert any(t["id"] == trip_id for t in publico)

        created = client.post(
            f"/requests/trips/{trip_id}",
            headers={"Authorization": f"Bearer {passenger_token}"},
        )
        assert created.status_code == 201
        assert created.json()["seat_count"] == 1
        request_id = created.json()["id"]

        accepted = client.patch(
            f"/requests/{request_id}/accept",
            headers={"Authorization": f"Bearer {driver_token}"},
        )
        assert accepted.status_code == 200

        # El viaje ya no tiene cupo: desaparece del listado publico.
        assert client.get(f"/trips/{trip_id}").json()["available_seats"] == 0

        # Pero sigue estando en las solicitudes del pasajero, con el conductor.
        propias = client.get(
            "/requests/me",
            headers={"Authorization": f"Bearer {passenger_token}"},
        )
        assert propias.status_code == 200
        listado = propias.json()
        assert len(listado) == 1
        assert listado[0]["trip_id"] == trip_id
        assert listado[0]["status"] == "accepted"
        assert listado[0]["driver_name"] == "Carla Conductora"
        assert listado[0]["driver_phone"] == "3120000001"
        assert listado[0]["origin"] == "Centro"
    finally:
        _limpiar(passenger_id, driver_id)


def test_retirar_solicitud_pendiente_no_toca_los_cupos():
    driver_id, driver_token = _crear_conductor("3120000003")
    passenger_id, passenger_token = _crear_pasajero("3120000004")

    try:
        trip_id = _viaje(driver_token, total_seats=2)
        created = client.post(
            f"/requests/trips/{trip_id}",
            headers={"Authorization": f"Bearer {passenger_token}"},
        )
        request_id = created.json()["id"]

        # Sin confirmar, el cupo nunca se habia descontado.
        assert client.get(f"/trips/{trip_id}").json()["available_seats"] == 2

        borrada = client.delete(
            f"/requests/{request_id}",
            headers={"Authorization": f"Bearer {passenger_token}"},
        )
        assert borrada.status_code == 204

        assert client.get(f"/trips/{trip_id}").json()["available_seats"] == 2
        assert (
            client.get(
                "/requests/me", headers={"Authorization": f"Bearer {passenger_token}"}
            ).json()
            == []
        )
    finally:
        _limpiar(passenger_id, driver_id)


def test_retirar_solicitud_confirmada_devuelve_el_cupo():
    driver_id, driver_token = _crear_conductor("3120000005")
    passenger_id, passenger_token = _crear_pasajero("3120000006")

    try:
        trip_id = _viaje(driver_token, total_seats=2)
        created = client.post(
            f"/requests/trips/{trip_id}",
            headers={"Authorization": f"Bearer {passenger_token}"},
        )
        request_id = created.json()["id"]
        client.patch(
            f"/requests/{request_id}/accept",
            headers={"Authorization": f"Bearer {driver_token}"},
        )
        assert client.get(f"/trips/{trip_id}").json()["available_seats"] == 1

        borrada = client.delete(
            f"/requests/{request_id}",
            headers={"Authorization": f"Bearer {passenger_token}"},
        )
        assert borrada.status_code == 204

        # El cupo vuelve al viaje.
        assert client.get(f"/trips/{trip_id}").json()["available_seats"] == 2
    finally:
        _limpiar(passenger_id, driver_id)


def test_retirar_una_solicitud_ajena_da_403():
    driver_id, driver_token = _crear_conductor("3120000007")
    passenger_id, passenger_token = _crear_pasajero("3120000008")
    otro_id, otro_token = _crear_pasajero("3120000009")

    try:
        trip_id = _viaje(driver_token, total_seats=2)
        created = client.post(
            f"/requests/trips/{trip_id}",
            headers={"Authorization": f"Bearer {passenger_token}"},
        )
        request_id = created.json()["id"]

        respuesta = client.delete(
            f"/requests/{request_id}",
            headers={"Authorization": f"Bearer {otro_token}"},
        )
        assert respuesta.status_code == 403

        # La solicitud sigue intacta.
        assert (
            len(
                client.get(
                    "/requests/me", headers={"Authorization": f"Bearer {passenger_token}"}
                ).json()
            )
            == 1
        )
    finally:
        _limpiar(otro_id, passenger_id, driver_id)


def test_tras_retirar_se_puede_volver_a_solicitar():
    """`create_request` bloquea si hay una `pending` o `accepted`.

    Retirar borra la fila justamente para que el pasajero pueda volver a
    pedir cupo en el mismo viaje.
    """
    driver_id, driver_token = _crear_conductor("3120000010")
    passenger_id, passenger_token = _crear_pasajero("3120000011")

    try:
        trip_id = _viaje(driver_token, total_seats=2)
        primera = client.post(
            f"/requests/trips/{trip_id}",
            headers={"Authorization": f"Bearer {passenger_token}"},
        )
        assert primera.status_code == 201

        # Mientras esta viva, una segunda peticion se rechaza.
        repetida = client.post(
            f"/requests/trips/{trip_id}",
            headers={"Authorization": f"Bearer {passenger_token}"},
        )
        assert repetida.status_code == 400

        client.delete(
            f"/requests/{primera.json()['id']}",
            headers={"Authorization": f"Bearer {passenger_token}"},
        )

        otra = client.post(
            f"/requests/trips/{trip_id}",
            headers={"Authorization": f"Bearer {passenger_token}"},
        )
        assert otra.status_code == 201
    finally:
        _limpiar(passenger_id, driver_id)


def test_retirar_inexistente_da_404():
    _pasajero_id, token = _crear_pasajero("3120000012")
    try:
        respuesta = client.delete(
            "/requests/999999", headers={"Authorization": f"Bearer {token}"}
        )
        assert respuesta.status_code == 404
    finally:
        _limpiar()


def test_mis_solicitudes_requiere_token():
    assert client.get("/requests/me").status_code == 401


def test_reserva_grupal_de_cuatro_y_cancelacion_libera_todos_los_cupos():
    driver_id, driver_token = _crear_conductor("3120000020")
    passenger_id, passenger_token = _crear_pasajero("3120000021")

    try:
        trip_id = _viaje(driver_token, total_seats=4)
        created = client.post(
            f"/requests/trips/{trip_id}",
            headers={"Authorization": f"Bearer {passenger_token}"},
            json={"seat_count": 4},
        )
        assert created.status_code == 201
        request_id = created.json()["id"]
        assert created.json()["seat_count"] == 4
        assert client.get(f"/trips/{trip_id}").json()["available_seats"] == 4

        accepted = client.patch(
            f"/requests/{request_id}/accept",
            headers={"Authorization": f"Bearer {driver_token}"},
        )
        assert accepted.status_code == 200
        assert accepted.json()["seat_count"] == 4
        assert client.get(f"/trips/{trip_id}").json()["available_seats"] == 0
        driver_view = client.get(
            "/trips/my-trips", headers={"Authorization": f"Bearer {driver_token}"}
        )
        assert driver_view.status_code == 200
        assert driver_view.json()[0]["requests"][0]["seat_count"] == 4

        repeated_accept = client.patch(
            f"/requests/{request_id}/accept",
            headers={"Authorization": f"Bearer {driver_token}"},
        )
        assert repeated_accept.status_code == 200
        assert client.get(f"/trips/{trip_id}").json()["available_seats"] == 0

        own = client.get(
            "/requests/me", headers={"Authorization": f"Bearer {passenger_token}"}
        )
        assert own.status_code == 200
        assert own.json()[0]["seat_count"] == 4

        withdrawn = client.delete(
            f"/requests/{request_id}",
            headers={"Authorization": f"Bearer {passenger_token}"},
        )
        assert withdrawn.status_code == 204
        assert client.get(f"/trips/{trip_id}").json()["available_seats"] == 4

        repeated_withdraw = client.delete(
            f"/requests/{request_id}",
            headers={"Authorization": f"Bearer {passenger_token}"},
        )
        assert repeated_withdraw.status_code == 404
        assert client.get(f"/trips/{trip_id}").json()["available_seats"] == 4
    finally:
        _limpiar(passenger_id, driver_id)


def test_solicitud_grupal_rechaza_cantidades_fuera_de_uno_a_cuatro():
    driver_id, driver_token = _crear_conductor("3120000022")
    passenger_id, passenger_token = _crear_pasajero("3120000023")

    try:
        trip_id = _viaje(driver_token, total_seats=4)
        for seat_count in (0, 5):
            response = client.post(
                f"/requests/trips/{trip_id}",
                headers={"Authorization": f"Bearer {passenger_token}"},
                json={"seat_count": seat_count},
            )
            assert response.status_code == 422
    finally:
        _limpiar(passenger_id, driver_id)


def test_solicitud_grupal_no_se_acepta_parcialmente():
    driver_id, driver_token = _crear_conductor("3120000024")
    group_id, group_token = _crear_pasajero("3120000025")
    other_id, other_token = _crear_pasajero("3120000026")

    try:
        trip_id = _viaje(driver_token, total_seats=4)
        group = client.post(
            f"/requests/trips/{trip_id}",
            headers={"Authorization": f"Bearer {group_token}"},
            json={"seat_count": 4},
        )
        other = client.post(
            f"/requests/trips/{trip_id}",
            headers={"Authorization": f"Bearer {other_token}"},
            json={"seat_count": 1},
        )
        assert group.status_code == other.status_code == 201

        accepted_other = client.patch(
            f"/requests/{other.json()['id']}/accept",
            headers={"Authorization": f"Bearer {driver_token}"},
        )
        assert accepted_other.status_code == 200

        accepted_group = client.patch(
            f"/requests/{group.json()['id']}/accept",
            headers={"Authorization": f"Bearer {driver_token}"},
        )
        assert accepted_group.status_code == 409
        assert client.get(f"/trips/{trip_id}").json()["available_seats"] == 3
        own = client.get(
            "/requests/me", headers={"Authorization": f"Bearer {group_token}"}
        )
        assert own.json()[0]["status"] == "pending"
    finally:
        _limpiar(other_id, group_id, driver_id)


def test_aceptaciones_grupales_concurrentes_no_sobrevenden():
    from concurrent.futures import ThreadPoolExecutor

    driver_id, driver_token = _crear_conductor("3120000027")
    group_a_id, group_a_token = _crear_pasajero("3120000028")
    group_b_id, group_b_token = _crear_pasajero("3120000029")

    try:
        trip_id = _viaje(driver_token, total_seats=4)
        request_ids = []
        for token in (group_a_token, group_b_token):
            created = client.post(
                f"/requests/trips/{trip_id}",
                headers={"Authorization": f"Bearer {token}"},
                json={"seat_count": 3},
            )
            assert created.status_code == 201
            request_ids.append(created.json()["id"])

        def accept(request_id: int) -> int:
            response = client.patch(
                f"/requests/{request_id}/accept",
                headers={"Authorization": f"Bearer {driver_token}"},
            )
            return response.status_code

        with ThreadPoolExecutor(max_workers=2) as executor:
            results = list(executor.map(accept, request_ids))

        assert sorted(results) == [200, 409]
        trip = client.get(f"/trips/{trip_id}").json()
        assert trip["available_seats"] == 1
    finally:
        _limpiar(group_b_id, group_a_id, driver_id)
