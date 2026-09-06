from concurrent.futures import ThreadPoolExecutor
from time import perf_counter

from fastapi.testclient import TestClient

from app.core.database import SessionLocal
from app.main import app
from app.modules.trips.models import Trip
from app.modules.trips.service import reserve_seat


client = TestClient(app)


def test_crear_consultar_y_reservar_cupo():
    response = client.post(
        "/trips/",
        json={"origin": "Campus", "destination": "Centro", "total_seats": 2},
    )
    assert response.status_code == 201
    trip_id = response.json()["id"]

    response = client.get(f"/trips/{trip_id}")
    assert response.status_code == 200
    assert response.json()["available_seats"] == 2

    response = client.post(f"/trips/{trip_id}/reservations")
    assert response.status_code == 200
    assert response.json()["available_seats"] == 1


def test_reservas_concurrentes_no_sobrevenden_cupos():
    with SessionLocal() as db:
        trip = Trip(
            origin="Campus",
            destination="Centro",
            total_seats=4,
            available_seats=4,
        )
        db.add(trip)
        db.commit()
        db.refresh(trip)
        trip_id = trip.id

    def reserve_once() -> tuple[bool, float]:
        started = perf_counter()
        with SessionLocal() as db:
            reserved = reserve_seat(db, trip_id) is not None
        return reserved, perf_counter() - started

    with ThreadPoolExecutor(max_workers=20) as executor:
        results = list(executor.map(lambda _: reserve_once(), range(20)))

    successful_reservations = sum(success for success, _ in results)
    durations = sorted(duration for _, duration in results)
    p95_duration = durations[18]

    with SessionLocal() as db:
        trip = db.get(Trip, trip_id)
        remaining_seats = trip.available_seats
        db.delete(trip)
        db.commit()

    assert successful_reservations == 4
    assert remaining_seats == 0
    assert p95_duration < 3.99
    print(
        f"cupos: 20 intentos, {successful_reservations} reservas exitosas, "
        f"p95={p95_duration:.4f}s"
    )
