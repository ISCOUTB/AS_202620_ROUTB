"""Pruebas de paradas en solicitudes (Fase 2 - Bloque 3.2)."""

from app.core.database import SessionLocal
from app.modules.requests.infrastructure.models import RequestStop

from tests.helpers import (
    STOP_LAT,
    STOP_LNG,
    client,
    crear_usuario as _crear_usuario_base,
    crear_viaje as _crear_viaje_base,
    limpiar as _limpiar_base,
    parada as _parada_base,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _crear_usuario(telefono: str, role: str = "passenger") -> tuple[int, str]:
    return _crear_usuario_base(telefono, role, apellido="Stops")


def _limpiar(*user_ids: int) -> None:
    _limpiar_base(*user_ids)


def _crear_viaje(driver_token: str, total_seats: int = 4, direction: str = "to_campus") -> int:
    return _crear_viaje_base(driver_token, total_seats, direction)


def _stop(seats: int = 1, lat: float = STOP_LAT, lng: float = STOP_LNG) -> dict:
    return _parada_base(seats, lat, lng)


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

def test_grupo_cuatro_cupos_tres_paradas_from_campus():
    """from_campus: 4 cupos con paradas 2+1+1 (sum == seat_count) debe aceptarse."""
    driver_id, driver_token = _crear_usuario("3300000001", "driver")
    passenger_id, passenger_token = _crear_usuario("3300000002", "passenger")

    try:
        trip_id = _crear_viaje(driver_token, total_seats=4, direction="from_campus")
        resp = client.post(
            f"/requests/trips/{trip_id}",
            headers={"Authorization": f"Bearer {passenger_token}"},
            json={
                "seat_count": 4,
                "stops": [
                    _stop(2, STOP_LAT, STOP_LNG),
                    _stop(1, 10.43, -75.53),
                    _stop(1, 10.41, -75.55),
                ],
            },
        )
        assert resp.status_code == 201
        assert resp.json()["seat_count"] == 4
        assert len(resp.json()["stops"]) == 3
    finally:
        _limpiar(passenger_id, driver_id)


def test_suma_seats_distinta_de_seat_count_da_422():
    """La suma de `seats` en paradas distinta de `seat_count` → 422."""
    driver_id, driver_token = _crear_usuario("3300000003", "driver")
    passenger_id, passenger_token = _crear_usuario("3300000004", "passenger")

    try:
        trip_id = _crear_viaje(driver_token, total_seats=4, direction="from_campus")
        resp = client.post(
            f"/requests/trips/{trip_id}",
            headers={"Authorization": f"Bearer {passenger_token}"},
            json={
                "seat_count": 3,
                "stops": [_stop(1), _stop(1)],  # suma 2 != 3
            },
        )
        assert resp.status_code == 422
    finally:
        _limpiar(passenger_id, driver_id)


def test_to_campus_mas_de_una_parada_da_422():
    """to_campus con más de una parada → 422."""
    driver_id, driver_token = _crear_usuario("3300000005", "driver")
    passenger_id, passenger_token = _crear_usuario("3300000006", "passenger")

    try:
        trip_id = _crear_viaje(driver_token, total_seats=4, direction="to_campus")
        resp = client.post(
            f"/requests/trips/{trip_id}",
            headers={"Authorization": f"Bearer {passenger_token}"},
            json={
                "seat_count": 2,
                "stops": [_stop(1), _stop(1)],  # 2 paradas en to_campus → error
            },
        )
        assert resp.status_code == 422
    finally:
        _limpiar(passenger_id, driver_id)


def test_borrar_solicitud_borra_sus_paradas():
    """Al retirar una solicitud sus paradas desaparecen de la base de datos."""
    driver_id, driver_token = _crear_usuario("3300000007", "driver")
    passenger_id, passenger_token = _crear_usuario("3300000008", "passenger")

    try:
        trip_id = _crear_viaje(driver_token, total_seats=4, direction="from_campus")
        created = client.post(
            f"/requests/trips/{trip_id}",
            headers={"Authorization": f"Bearer {passenger_token}"},
            json={
                "seat_count": 2,
                "stops": [_stop(1), _stop(1, 10.43, -75.53)],
            },
        )
        assert created.status_code == 201
        req_id = created.json()["id"]

        # Confirmar que las paradas existen
        with SessionLocal() as db:
            stops_count = db.query(RequestStop).filter(
                RequestStop.request_id == req_id
            ).count()
        assert stops_count == 2

        # Retirar la solicitud
        resp = client.delete(
            f"/requests/{req_id}",
            headers={"Authorization": f"Bearer {passenger_token}"},
        )
        assert resp.status_code == 204

        # Las paradas deben haber desaparecido (CASCADE)
        with SessionLocal() as db:
            stops_count = db.query(RequestStop).filter(
                RequestStop.request_id == req_id
            ).count()
        assert stops_count == 0
    finally:
        _limpiar(passenger_id, driver_id)


def test_solicitud_pendiente_no_expone_stop_geom():
    """Una solicitud pendiente no devuelve `stop_geom` en la respuesta JSON."""
    driver_id, driver_token = _crear_usuario("3300000009", "driver")
    passenger_id, passenger_token = _crear_usuario("3300000010", "passenger")

    try:
        trip_id = _crear_viaje(driver_token, total_seats=4, direction="from_campus")
        created = client.post(
            f"/requests/trips/{trip_id}",
            headers={"Authorization": f"Bearer {passenger_token}"},
            json={
                "seat_count": 1,
                "stops": [_stop(1)],
            },
        )
        assert created.status_code == 201
        stops = created.json()["stops"]
        assert len(stops) == 1
        # El schema no expone stop_geom
        assert "stop_geom" not in stops[0]
    finally:
        _limpiar(passenger_id, driver_id)


def test_paradas_de_solicitudes_distintas_se_intercalan():
    """Dos solicitudes diferentes pueden tener paradas; ambas coexisten sin conflicto."""
    driver_id, driver_token = _crear_usuario("3300000011", "driver")
    pass_a_id, pass_a_token = _crear_usuario("3300000012", "passenger")
    pass_b_id, pass_b_token = _crear_usuario("3300000013", "passenger")

    try:
        trip_id = _crear_viaje(driver_token, total_seats=4, direction="from_campus")
        r1 = client.post(
            f"/requests/trips/{trip_id}",
            headers={"Authorization": f"Bearer {pass_a_token}"},
            json={"seat_count": 1, "stops": [_stop(1, STOP_LAT, STOP_LNG)]},
        )
        r2 = client.post(
            f"/requests/trips/{trip_id}",
            headers={"Authorization": f"Bearer {pass_b_token}"},
            json={"seat_count": 1, "stops": [_stop(1, 10.43, -75.53)]},
        )
        assert r1.status_code == 201
        assert r2.status_code == 201
        assert r1.json()["id"] != r2.json()["id"]

        with SessionLocal() as db:
            total_stops = db.query(RequestStop).filter(
                RequestStop.request_id.in_([r1.json()["id"], r2.json()["id"]])
            ).count()
        assert total_stops == 2
    finally:
        _limpiar(pass_b_id, pass_a_id, driver_id)


def test_parada_desde_cualquier_ubicacion_es_aceptada():
    """Una parada con coordenadas fuera del BBOX de Cartagena es aceptada."""
    driver_id, driver_token = _crear_usuario("3300000014", "driver")
    passenger_id, passenger_token = _crear_usuario("3300000015", "passenger")

    try:
        trip_id = _crear_viaje(driver_token, total_seats=4, direction="to_campus")
        # Coordenadas fuera de Cartagena (ej. Turbaco sur / Arjona / Bogotá)
        resp = client.post(
            f"/requests/trips/{trip_id}",
            headers={"Authorization": f"Bearer {passenger_token}"},
            json={
                "seat_count": 1,
                "stops": [_stop(1, 4.6097, -74.0817)],
            },
        )
        assert resp.status_code == 201
        assert len(resp.json()["stops"]) == 1
    finally:
        _limpiar(passenger_id, driver_id)
<<<<<<< HEAD


def test_requests_me_consolida_todas_las_paradas_confirmadas_del_viaje():
    """GET /requests/me devuelve las paradas confirmadas de todas las solicitudes aceptadas."""
    driver_id, driver_token = _crear_usuario("3300000016", "driver")
    pass_a_id, pass_a_token = _crear_usuario("3300000017", "passenger")
    pass_b_id, pass_b_token = _crear_usuario("3300000018", "passenger")

    try:
        trip_id = _crear_viaje(driver_token, total_seats=4, direction="from_campus")

        # Pasajero A solicita parada
        r1 = client.post(
            f"/requests/trips/{trip_id}",
            headers={"Authorization": f"Bearer {pass_a_token}"},
            json={"seat_count": 1, "stops": [_stop(1, 10.41, -75.53)]},
        )
        assert r1.status_code == 201
        req_a_id = r1.json()["id"]

        # Conductor acepta a Pasajero A
        accept_a = client.patch(
            f"/requests/{req_a_id}/accept",
            headers={"Authorization": f"Bearer {driver_token}"},
        )
        assert accept_a.status_code == 200

        # Pasajero B solicita parada
        r2 = client.post(
            f"/requests/trips/{trip_id}",
            headers={"Authorization": f"Bearer {pass_b_token}"},
            json={"seat_count": 1, "stops": [_stop(1, 10.42, -75.52)]},
        )
        assert r2.status_code == 201
        req_b_id = r2.json()["id"]

        # Conductor acepta a Pasajero B
        accept_b = client.patch(
            f"/requests/{req_b_id}/accept",
            headers={"Authorization": f"Bearer {driver_token}"},
        )
        assert accept_b.status_code == 200

        # Pasajero A consulta sus viajes: ve las 2 paradas confirmadas
        me_a = client.get(
            "/requests/me",
            headers={"Authorization": f"Bearer {pass_a_token}"},
        )
        assert me_a.status_code == 200
        a_stops = me_a.json()[0]["stops"]
        assert len(a_stops) == 2

        # Pasajero B consulta sus viajes: también ve las 2 paradas confirmadas
        me_b = client.get(
            "/requests/me",
            headers={"Authorization": f"Bearer {pass_b_token}"},
        )
        assert me_b.status_code == 200
        b_stops = me_b.json()[0]["stops"]
        assert len(b_stops) == 2
    finally:
        _limpiar(pass_b_id, pass_a_id, driver_id)
=======
>>>>>>> origin/master
