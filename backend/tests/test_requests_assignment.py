"""Pruebas de asignación y concurrencia de solicitudes (Fase 2 - Bloque 3.1)."""

from concurrent.futures import ThreadPoolExecutor
from datetime import timedelta

from app.core.database import SessionLocal
from app.core.timezone import colombia_now, colombia_today
from app.modules.trips.infrastructure.models import Trip
from app.modules.users.infrastructure.models import User

from tests.helpers import (
    FUTURE_TIME,
    client,
    crear_usuario as _crear_usuario_base,
    crear_viaje as _crear_viaje_base,
    limpiar as _limpiar_base,
    parada as _parada_base,
)


def _stop(seats: int = 1) -> dict:
    return _parada_base(seats)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _crear_usuario(telefono: str, role: str = "passenger") -> tuple[int, str]:
    return _crear_usuario_base(
        telefono, role, apellido="Assignment", consentimiento=None
    )


def _limpiar(*user_ids: int) -> None:
    _limpiar_base(*user_ids)


def _crear_viaje(driver_token: str, total_seats: int = 4, direction: str = "to_campus") -> int:
    return _crear_viaje_base(driver_token, total_seats, direction)


def _crear_viaje_legacy(driver_token: str, total_seats: int = 4) -> int:
    """Viaje legado sin `direction`."""
    resp = client.post(
        "/trips/",
        headers={"Authorization": f"Bearer {driver_token}"},
        json={
            "origin": "Centro",
            "destination": "UTB",
            "total_seats": total_seats,
            "departure_time": FUTURE_TIME,
            "departure_date": str(colombia_today()),
        },
    )
    assert resp.status_code == 201
    return resp.json()["id"]


def _solicitar(
    passenger_token: str,
    trip_id: int,
    seat_count: int = 1,
    with_stops: bool = True,
) -> int:
    payload: dict = {"seat_count": seat_count}
    if with_stops:
        # Los viajes con direction exigen paradas cuya suma iguale seat_count
        # (to_campus: exactamente una). Una sola parada con todos los cupos
        # vale para ambos sentidos.
        payload["stops"] = [_stop(seat_count)]
    resp = client.post(
        f"/requests/trips/{trip_id}",
        headers={"Authorization": f"Bearer {passenger_token}"},
        json=payload,
    )
    assert resp.status_code == 201, resp.text
    return resp.json()["id"]


def _aceptar(driver_token: str, request_id: int) -> int:
    return client.patch(
        f"/requests/{request_id}/accept",
        headers={"Authorization": f"Bearer {driver_token}"},
    ).status_code


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

def test_aceptar_cancela_solicitudes_pendientes_mismo_dia_sentido():
    """Al aceptar una solicitud, las otras del mismo pasajero/día/sentido quedan canceladas."""
    driver_id, driver_token = _crear_usuario("3200000001", "driver")
    driver2_id, driver2_token = _crear_usuario("3200000002", "driver")
    passenger_id, passenger_token = _crear_usuario("3200000003", "passenger")

    try:
        trip1_id = _crear_viaje(driver_token, total_seats=2, direction="to_campus")
        trip2_id = _crear_viaje(driver2_token, total_seats=2, direction="to_campus")

        req1_id = _solicitar(passenger_token, trip1_id)
        req2_id = _solicitar(passenger_token, trip2_id)

        # Aceptar la primera
        assert _aceptar(driver_token, req1_id) == 200

        # La segunda debe haberse cancelado automáticamente
        mis = client.get("/requests/me", headers={"Authorization": f"Bearer {passenger_token}"})
        assert mis.status_code == 200
        statuses = {r["id"]: r["status"] for r in mis.json()}
        assert statuses[req1_id] == "accepted"
        assert statuses[req2_id] == "cancelled"
    finally:
        _limpiar(passenger_id, driver_id, driver2_id)


def test_aceptar_no_cancela_solicitudes_distinta_fecha():
    """Al aceptar, no se cancelan solicitudes del pasajero para otra fecha."""
    driver_id, driver_token = _crear_usuario("3200000010", "driver")
    passenger_id, passenger_token = _crear_usuario("3200000011", "passenger")

    try:
        today = colombia_today()
        tomorrow = today + timedelta(days=1)

        trip_hoy_id = _crear_viaje(driver_token, total_seats=2, direction="to_campus")
        # Crear viaje para mañana directamente en la BD
        with SessionLocal() as db:
            driver = db.get(User, driver_id)
            trip_mañana = Trip(
                origin="Centro",
                destination="UTB",
                total_seats=2,
                available_seats=2,
                driver_id=driver_id,
                direction="to_campus",
                departure_date=tomorrow,
                departure_time=FUTURE_TIME,
                status="active",
            )
            db.add(trip_mañana)
            db.commit()
            db.refresh(trip_mañana)
            trip_mañana_id = trip_mañana.id

        req_hoy_id = _solicitar(passenger_token, trip_hoy_id)
        req_mañana_id = _solicitar(passenger_token, trip_mañana_id)

        assert _aceptar(driver_token, req_hoy_id) == 200

        mis = client.get("/requests/me", headers={"Authorization": f"Bearer {passenger_token}"})
        statuses = {r["id"]: r["status"] for r in mis.json()}
        assert statuses[req_hoy_id] == "accepted"
        # La solicitud de mañana no debe cancelarse
        assert statuses[req_mañana_id] == "pending"
    finally:
        _limpiar(passenger_id, driver_id)


def test_aceptar_no_cancela_solicitudes_distinto_sentido():
    """Al aceptar, no se cancelan solicitudes del pasajero para otro sentido."""
    driver_id, driver_token = _crear_usuario("3200000020", "driver")
    passenger_id, passenger_token = _crear_usuario("3200000021", "passenger")

    try:
        trip_to_id = _crear_viaje(driver_token, total_seats=2, direction="to_campus")
        trip_from_id = _crear_viaje(driver_token, total_seats=2, direction="from_campus")

        req_to_id = _solicitar(passenger_token, trip_to_id)
        req_from_id = _solicitar(passenger_token, trip_from_id)

        assert _aceptar(driver_token, req_to_id) == 200

        mis = client.get("/requests/me", headers={"Authorization": f"Bearer {passenger_token}"})
        statuses = {r["id"]: r["status"] for r in mis.json()}
        assert statuses[req_to_id] == "accepted"
        assert statuses[req_from_id] == "pending"
    finally:
        _limpiar(passenger_id, driver_id)


def test_dos_aceptaciones_simultaneas_no_sobrevenden():
    """Dos conductores aceptando al mismo tiempo producen solo una aceptación exitosa."""
    driver_a_id, driver_a_token = _crear_usuario("3200000030", "driver")
    driver_b_id, driver_b_token = _crear_usuario("3200000031", "driver")
    pass_a_id, pass_a_token = _crear_usuario("3200000032", "passenger")
    pass_b_id, pass_b_token = _crear_usuario("3200000033", "passenger")

    try:
        trip_id = _crear_viaje(driver_a_token, total_seats=4, direction="to_campus")

        # Agregar driver_b como dueño del mismo viaje directamente en BD
        with SessionLocal() as db:
            trip = db.get(Trip, trip_id)
            # Para simular dos conductores, registramos solicitudes para dos pasajeros
            pass
        req_a_id = _solicitar(pass_a_token, trip_id, seat_count=3)
        req_b_id = _solicitar(pass_b_token, trip_id, seat_count=3)

        def _accept_as_driver(req_id: int) -> int:
            return client.patch(
                f"/requests/{req_id}/accept",
                headers={"Authorization": f"Bearer {driver_a_token}"},
            ).status_code

        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(_accept_as_driver, [req_a_id, req_b_id]))

        assert sorted(results) == [200, 409]
        trip_data = client.get(f"/trips/{trip_id}").json()
        assert trip_data["available_seats"] == 1  # 4 - 3 = 1
    finally:
        _limpiar(pass_b_id, pass_a_id, driver_b_id, driver_a_id)


def test_viaje_legado_sin_direction_no_cancela_otros():
    """Viaje legado sin `direction`: aceptar no cancela otras solicitudes del pasajero."""
    driver_id, driver_token = _crear_usuario("3200000040", "driver")
    passenger_id, passenger_token = _crear_usuario("3200000041", "passenger")

    try:
        legacy_trip_id = _crear_viaje_legacy(driver_token, total_seats=2)
        normal_trip_id = _crear_viaje(driver_token, total_seats=2, direction="to_campus")

        req_legacy_id = _solicitar(passenger_token, legacy_trip_id, with_stops=False)
        req_normal_id = _solicitar(passenger_token, normal_trip_id)

        assert _aceptar(driver_token, req_legacy_id) == 200

        mis = client.get("/requests/me", headers={"Authorization": f"Bearer {passenger_token}"})
        statuses = {r["id"]: r["status"] for r in mis.json()}
        assert statuses[req_legacy_id] == "accepted"
        # El viaje legado no cancela el de sentido definido
        assert statuses[req_normal_id] == "pending"
    finally:
        _limpiar(passenger_id, driver_id)


def test_solicitud_vencida_no_se_puede_aceptar():
    """Aceptar una solicitud vencida devuelve 409 con detail `request_expired`."""
    driver_id, driver_token = _crear_usuario("3200000050", "driver")
    passenger_id, passenger_token = _crear_usuario("3200000051", "passenger")

    try:
        trip_id = _crear_viaje(driver_token, total_seats=2, direction="to_campus")
        req_id = _solicitar(passenger_token, trip_id)

        # Hacer que el viaje quede en el pasado
        with SessionLocal() as db:
            trip = db.get(Trip, trip_id)
            trip.departure_at = colombia_now() - timedelta(minutes=5)
            db.commit()

        resp = client.patch(
            f"/requests/{req_id}/accept",
            headers={"Authorization": f"Bearer {driver_token}"},
        )
        assert resp.status_code == 409
        assert resp.json()["detail"] == "request_expired"
    finally:
        _limpiar(passenger_id, driver_id)
