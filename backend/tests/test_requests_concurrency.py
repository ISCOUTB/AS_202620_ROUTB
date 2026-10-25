"""Concurrencia del flujo real de solicitudes y cupos.

Complementa ``test_cupos.py`` (camino atómico ``reserve_seat`` del ADR 0003)
con el flujo que usa la app: crear solicitud y aceptarla. Se ejecuta contra
PostgreSQL, donde las actualizaciones condicionales y el índice único parcial
de solicitudes activas tienen efecto real.

Casos cubiertos:
- Varias aceptaciones simultáneas no sobrevenden ni dejan cupos negativos.
- Creaciones simultáneas del mismo pasajero dejan una sola solicitud activa.
- Aceptar y retirar a la vez no duplica la liberación de cupos.
- Aceptar y rechazar a la vez dejan un estado y unos cupos consistentes.
- Aceptar un grupo sin cupos suficientes no descuenta parcialmente.
"""

from concurrent.futures import ThreadPoolExecutor
from math import ceil
from time import perf_counter

from app.core.database import SessionLocal
from app.modules.requests.infrastructure.models import TripRequest
from app.modules.trips.infrastructure.models import Trip

from tests.helpers import (
    client,
    crear_usuario,
    crear_viaje,
    limpiar,
    parada,
)

CONCURRENT_ATTEMPTS = 8
SEAT_CAPACITY = 4


def _solicitar(passenger_token: str, trip_id: int, seat_count: int = 1):
    return client.post(
        f"/requests/trips/{trip_id}",
        headers={"Authorization": f"Bearer {passenger_token}"},
        json={"seat_count": seat_count, "stops": [parada(seat_count)]},
    )


def _aceptar(driver_token: str, request_id: int):
    return client.patch(
        f"/requests/{request_id}/accept",
        headers={"Authorization": f"Bearer {driver_token}"},
    )


def _retirar(passenger_token: str, request_id: int):
    return client.delete(
        f"/requests/{request_id}",
        headers={"Authorization": f"Bearer {passenger_token}"},
    )


def _rechazar(driver_token: str, request_id: int):
    return client.patch(
        f"/requests/{request_id}/reject",
        headers={"Authorization": f"Bearer {driver_token}"},
    )


def _cupos(trip_id: int) -> int:
    return client.get(f"/trips/{trip_id}").json()["available_seats"]


def _p95(durations: list[float]) -> float:
    ordered = sorted(durations)
    return ordered[ceil(0.95 * len(ordered)) - 1]


def test_aceptaciones_concurrentes_respetan_los_cupos(monkeypatch):
    """Ocho aceptaciones simultáneas sobre cuatro cupos: exactamente cuatro.

    El recálculo de ruta posterior a la aceptación llama a OSRM y su limitador
    de 1 req/s; se aísla para medir la contención de cupos en la base de datos,
    no la latencia del proveedor externo (que tiene sus propias pruebas).
    """
    monkeypatch.setattr(
        "app.modules.requests.application.manage_request.refresh_trip_route_and_stop_eta",
        lambda db, trip_id: None,
    )
    driver_id, driver_token = crear_usuario("3331000001", "driver")
    passenger_ids: list[int] = []
    request_ids: list[int] = []

    try:
        trip_id = crear_viaje(
            driver_token, total_seats=SEAT_CAPACITY, direction="to_campus"
        )
        for index in range(CONCURRENT_ATTEMPTS):
            passenger_id, passenger_token = crear_usuario(
                f"33310001{index:02d}", "passenger"
            )
            passenger_ids.append(passenger_id)
            created = _solicitar(passenger_token, trip_id)
            assert created.status_code == 201, created.text
            request_ids.append(created.json()["id"])

        def accept(request_id: int) -> tuple[int, float]:
            started = perf_counter()
            response = _aceptar(driver_token, request_id)
            return response.status_code, perf_counter() - started

        with ThreadPoolExecutor(max_workers=CONCURRENT_ATTEMPTS) as executor:
            results = list(executor.map(accept, request_ids))

        codes = [code for code, _ in results]
        durations = [duration for _, duration in results]
        assert codes.count(200) == SEAT_CAPACITY
        assert codes.count(409) == CONCURRENT_ATTEMPTS - SEAT_CAPACITY
        assert _cupos(trip_id) == 0

        with SessionLocal() as db:
            trip = db.get(Trip, trip_id)
            assert trip.available_seats == 0
            assert trip.available_seats >= 0

        listed = client.get(
            f"/requests/trips/{trip_id}",
            headers={"Authorization": f"Bearer {driver_token}"},
        )
        assert listed.status_code == 200
        statuses = [item["status"] for item in listed.json()]
        assert statuses.count("accepted") == SEAT_CAPACITY

        # Informativo: la latencia depende de la base de pruebas configurada.
        # El umbral duro p95 < 3,99 s se conserva en test_cupos.py, que corre
        # contra PostgreSQL local en CI (ADR 0003).
        print(
            f"aceptaciones concurrentes: {CONCURRENT_ATTEMPTS} intentos, "
            f"{codes.count(200)} aceptadas, p95={_p95(durations):.4f}s"
        )
    finally:
        limpiar(*passenger_ids, driver_id)


def test_creaciones_simultaneas_del_mismo_pasajero_dejan_una_activa():
    """Dos envíos simultáneos del mismo pasajero no crean dos solicitudes activas."""
    driver_id, driver_token = crear_usuario("3331000020", "driver")
    passenger_id, passenger_token = crear_usuario("3331000021", "passenger")

    try:
        trip_id = crear_viaje(driver_token, total_seats=4, direction="to_campus")

        with ThreadPoolExecutor(max_workers=CONCURRENT_ATTEMPTS) as executor:
            responses = list(
                executor.map(
                    lambda _: _solicitar(passenger_token, trip_id),
                    range(CONCURRENT_ATTEMPTS),
                )
            )

        codes = sorted(response.status_code for response in responses)
        assert codes.count(201) == 1
        assert codes.count(400) == CONCURRENT_ATTEMPTS - 1

        with SessionLocal() as db:
            active = (
                db.query(TripRequest)
                .filter(
                    TripRequest.trip_id == trip_id,
                    TripRequest.passenger_id == passenger_id,
                    TripRequest.status.in_(["pending", "accepted"]),
                )
                .count()
            )
        assert active == 1
    finally:
        limpiar(passenger_id, driver_id)


def test_aceptar_y_retirar_simultaneamente_no_descuadran_los_cupos():
    """Aceptar y retirar la misma solicitud deja los cupos completos."""
    driver_id, driver_token = crear_usuario("3331000030", "driver")
    passenger_id, passenger_token = crear_usuario("3331000031", "passenger")

    try:
        trip_id = crear_viaje(driver_token, total_seats=2, direction="to_campus")
        created = _solicitar(passenger_token, trip_id)
        assert created.status_code == 201, created.text
        request_id = created.json()["id"]

        with ThreadPoolExecutor(max_workers=2) as executor:
            accept_future = executor.submit(_aceptar, driver_token, request_id)
            withdraw_future = executor.submit(_retirar, passenger_token, request_id)
            accept_code = accept_future.result().status_code
            withdraw_code = withdraw_future.result().status_code

        assert withdraw_code == 204
        assert accept_code in (200, 404)
        assert _cupos(trip_id) == 2

        with SessionLocal() as db:
            trip = db.get(Trip, trip_id)
            assert trip.available_seats == trip.total_seats
            remaining = (
                db.query(TripRequest).filter(TripRequest.id == request_id).count()
            )
        assert remaining == 0
    finally:
        limpiar(passenger_id, driver_id)


def test_aceptar_y_rechazar_simultaneamente_dejan_estado_consistente():
    """Aceptar y rechazar a la vez no dejan cupos fuera de rango."""
    driver_id, driver_token = crear_usuario("3331000040", "driver")
    passenger_id, passenger_token = crear_usuario("3331000041", "passenger")

    try:
        trip_id = crear_viaje(driver_token, total_seats=1, direction="to_campus")
        created = _solicitar(passenger_token, trip_id)
        assert created.status_code == 201, created.text
        request_id = created.json()["id"]

        with ThreadPoolExecutor(max_workers=2) as executor:
            accept_future = executor.submit(_aceptar, driver_token, request_id)
            reject_future = executor.submit(_rechazar, driver_token, request_id)
            accept_code = accept_future.result().status_code
            reject_code = reject_future.result().status_code

        assert {accept_code, reject_code} <= {200, 409}
        assert 200 in {accept_code, reject_code}

        with SessionLocal() as db:
            trip = db.get(Trip, trip_id)
            request = db.get(TripRequest, request_id)
            assert request.status in ("accepted", "rejected")
            expected_seats = 1 if request.status == "rejected" else 0
            assert trip.available_seats == expected_seats
            assert 0 <= trip.available_seats <= trip.total_seats
    finally:
        limpiar(passenger_id, driver_id)


def test_grupo_sin_cupos_no_descuenta_parcialmente():
    """Si el grupo no cabe, la aceptación falla sin tocar los cupos."""
    driver_id, driver_token = crear_usuario("3331000050", "driver")
    passenger_a_id, passenger_a_token = crear_usuario("3331000051", "passenger")
    passenger_b_id, passenger_b_token = crear_usuario("3331000052", "passenger")

    try:
        trip_id = crear_viaje(driver_token, total_seats=3, direction="from_campus")
        request_a = _solicitar(passenger_a_token, trip_id, seat_count=2)
        request_b = _solicitar(passenger_b_token, trip_id, seat_count=2)
        assert request_a.status_code == 201, request_a.text
        assert request_b.status_code == 201, request_b.text

        accepted_a = _aceptar(driver_token, request_a.json()["id"])
        assert accepted_a.status_code == 200, accepted_a.text
        assert _cupos(trip_id) == 1

        rejected_b = _aceptar(driver_token, request_b.json()["id"])
        assert rejected_b.status_code == 409
        assert _cupos(trip_id) == 1

        with SessionLocal() as db:
            request = db.get(TripRequest, request_b.json()["id"])
            assert request.status == "pending"
            trip = db.get(Trip, trip_id)
            assert trip.available_seats == 1
    finally:
        limpiar(passenger_b_id, passenger_a_id, driver_id)
