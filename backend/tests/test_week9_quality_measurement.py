from math import ceil
from time import perf_counter

from fastapi.testclient import TestClient

from app.core.database import SessionLocal
from app.main import app
from app.modules.trips.infrastructure.models import Trip


def test_get_trips_hot_100_responses_under_published_threshold():
    with SessionLocal() as db:
        trip = Trip(
            origin="Campus",
            destination="Centro",
            total_seats=4,
            available_seats=4,
            departure_time="7:00 AM",
        )
        db.add(trip)
        db.commit()
        trip_id = trip.id

    client = TestClient(app)
    try:
        assert client.get("/health").status_code == 200
        durations = []
        for _ in range(100):
            started = perf_counter()
            response = client.get("/trips/")
            durations.append(perf_counter() - started)
            assert response.status_code == 200

        p95 = sorted(durations)[ceil(len(durations) * 0.95) - 1]
        assert len(durations) == 100
        assert p95 < 3.99
        print(
            "GET /trips/ local caliente: "
            f"N=100, p95={p95:.4f}s, umbral=3.99s"
        )
    finally:
        with SessionLocal() as db:
            saved_trip = db.get(Trip, trip_id)
            if saved_trip is not None:
                db.delete(saved_trip)
                db.commit()
