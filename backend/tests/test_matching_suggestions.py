"""Pruebas del módulo de matching y sugerencias de viajes (Fase 2)."""

import json
from math import ceil
from datetime import date, timedelta
from time import perf_counter
from uuid import uuid4
from unittest.mock import MagicMock

import pytest
import httpx
from fastapi.testclient import TestClient

from app.core.database import SessionLocal
from app.modules.auth.application.tokens import create_access_token
from app.core.timezone import colombia_now, colombia_today
from app.main import app
from app.modules.trips.infrastructure.models import Trip
from app.modules.users.infrastructure.models import User

client = TestClient(app)


def _create_user(role="passenger", has_consent=True) -> tuple[User, str]:
    db = SessionLocal()
    phone = f"300{uuid4().int % 10_000_000:07d}"
    user = User(
        name="Test",
        last_name="User",
        phone=phone,
        hashed_password="hash",
        role=role,
        location_consent_at=colombia_now() if has_consent else None,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    token = create_access_token(user.id, user.role)
    db.close()
    return user, token


def _create_trip_with_route(
    driver_id: int,
    direction: str = "to_campus",
    origin_coords: tuple[float, float] = (10.4236, -75.5478),  # Centro
    dest_coords: tuple[float, float] = (10.371078, -75.466261),  # UTB
    available_seats: int = 3,
    departure_time: str = "07:00 AM",
    trip_date: date | None = None,
) -> Trip:
    db = SessionLocal()
    t_date = trip_date or colombia_today()

    # Línea simple entre origen y destino
    line_coords = [
        [origin_coords[1], origin_coords[0]],
        [dest_coords[1], dest_coords[0]],
    ]
    line_geojson = json.dumps({"type": "LineString", "coordinates": line_coords})
    orig_geojson = json.dumps({"type": "Point", "coordinates": [origin_coords[1], origin_coords[0]]})
    dest_geojson = json.dumps({"type": "Point", "coordinates": [dest_coords[1], dest_coords[0]]})

    from geoalchemy2.functions import ST_GeomFromGeoJSON

    trip = Trip(
        origin="Centro",
        destination="UTB Campus",
        total_seats=4,
        available_seats=available_seats,
        driver_id=driver_id,
        direction=direction,
        departure_date=t_date,
        departure_time=departure_time,
        departure_at=colombia_now().replace(hour=7, minute=0, second=0, microsecond=0),
        route_distance_m=12000,
        route_duration_s=1500,
        route_source="osrm",
        origin_geom=ST_GeomFromGeoJSON(orig_geojson),
        dest_geom=ST_GeomFromGeoJSON(dest_geojson),
        route_geom=ST_GeomFromGeoJSON(line_geojson),
        status="active",
    )
    db.add(trip)
    db.commit()
    db.refresh(trip)
    t_id = trip.id
    db.close()

    # Reabrir para obtener el objeto limpio
    db2 = SessionLocal()
    saved = db2.query(Trip).filter(Trip.id == t_id).first()
    db2.close()
    return saved


def test_matching_requires_location_consent():
    """Sin consentimiento de ubicación, debe responder 403 location_consent_required."""
    _, token = _create_user(role="passenger", has_consent=False)
    resp = client.get(
        "/matching/suggestions",
        params={
            "direction": "to_campus",
            "points": "10.4236,-75.5478",
            "date": str(colombia_today()),
            "time": "07:00 AM",
        },
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 403
    assert resp.json()["detail"] == "location_consent_required"


def test_matching_validates_bbox():
    """Puntos fuera de Cartagena (BBOX) deben responder 422."""
    _, token = _create_user(role="passenger", has_consent=True)
    # Coordenadas en Bogotá
    resp = client.get(
        "/matching/suggestions",
        params={
            "direction": "to_campus",
            "points": "4.6097,-74.0817",
            "date": str(colombia_today()),
            "time": "07:00 AM",
        },
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 422


def test_matching_empty_results_returns_200_empty_list():
    """Si no hay viajes en esa fecha o dirección, responde 200 []."""
    _, token = _create_user(role="passenger", has_consent=True)
    future_date = colombia_today() + timedelta(days=20)
    resp = client.get(
        "/matching/suggestions",
        params={
            "direction": "to_campus",
            "points": "10.4236,-75.5478",
            "date": str(future_date),
            "time": "07:00 AM",
        },
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200
    assert resp.json() == []


def test_matching_suggests_compatible_trip():
    """Viaje compatible en ruta devuelve sugerencia con score y eta."""
    driver, _ = _create_user(role="driver", has_consent=True)
    passenger, p_token = _create_user(role="passenger", has_consent=True)

    today = colombia_today()
    trip = _create_trip_with_route(
        driver_id=driver.id,
        direction="to_campus",
        origin_coords=(10.4236, -75.5478),
        dest_coords=(10.371078, -75.466261),
        available_seats=3,
        departure_time="07:00 AM",
        trip_date=today,
    )

    # El punto del pasajero está muy cerca del origen del conductor
    resp = client.get(
        "/matching/suggestions",
        params={
            "direction": "to_campus",
            "points": "10.4236,-75.5478",
            "date": str(today),
            "time": "07:00 AM",
            "seat_count": 2,
        },
        headers={"Authorization": f"Bearer {p_token}"},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert len(data) >= 1
    item = next(it for it in data if it["trip_id"] == trip.id)
    assert item["driver_name"] == f"{driver.name} {driver.last_name}"
    assert item["available_seats"] == 3
    assert item["walk_distance_m"] >= 0
    assert "score" in item
    assert "detour_minutes" in item
    assert item["eta_pickup"] is not None


def test_matching_excludes_driver_own_trip():
    """El conductor no puede recibir su propio viaje como sugerencia."""
    driver, d_token = _create_user(role="driver", has_consent=True)
    today = colombia_today()
    trip = _create_trip_with_route(
        driver_id=driver.id,
        direction="to_campus",
        trip_date=today,
    )

    resp = client.get(
        "/matching/suggestions",
        params={
            "direction": "to_campus",
            "points": "10.4236,-75.5478",
            "date": str(today),
            "time": "07:00 AM",
        },
        headers={"Authorization": f"Bearer {d_token}"},
    )
    assert resp.status_code == 200
    # No debe contener el viaje del mismo conductor
    ids = [it["trip_id"] for it in resp.json()]
    assert trip.id not in ids


def test_matching_excludes_legacy_trips_without_route():
    """Viajes legados sin route_geom no deben aparecer en las sugerencias."""
    driver, _ = _create_user(role="driver", has_consent=True)
    _, p_token = _create_user(role="passenger", has_consent=True)

    db = SessionLocal()
    today = colombia_today()
    legacy_trip = Trip(
        origin="Centro",
        destination="UTB",
        total_seats=4,
        available_seats=4,
        driver_id=driver.id,
        direction=None,
        route_geom=None,
        departure_date=today,
        departure_time="07:00 AM",
        status="active",
    )
    db.add(legacy_trip)
    db.commit()
    db.refresh(legacy_trip)
    legacy_id = legacy_trip.id
    db.close()

    resp = client.get(
        "/matching/suggestions",
        params={
            "direction": "to_campus",
            "points": "10.4236,-75.5478",
            "date": str(today),
            "time": "07:00 AM",
        },
        headers={"Authorization": f"Bearer {p_token}"},
    )
    assert resp.status_code == 200
    ids = [it["trip_id"] for it in resp.json()]
    assert legacy_id not in ids


def test_matching_osrm_timeout_50_responses_remain_contractual(monkeypatch):
    """Mide 50 respuestas de matching con OSRM fallando de forma inyectada."""
    driver, _ = _create_user(role="driver", has_consent=True)
    _, passenger_token = _create_user(role="passenger", has_consent=True)
    trip = _create_trip_with_route(driver_id=driver.id, direction="to_campus")

    # Asegurar que el fallback no descarte la sugerencia por desvío en este caso.
    with SessionLocal() as db:
        saved_trip = db.get(Trip, trip.id)
        saved_trip.route_duration_s = 3600
        db.commit()

    route_client = MagicMock()
    route_client.__enter__.return_value = route_client
    route_client.get.side_effect = httpx.TimeoutException("timeout inyectado")
    monkeypatch.setattr("app.shared.routing.service.httpx.Client", lambda **_: route_client)
    monkeypatch.setattr("app.shared.routing.service._osrm_last_call", 0.0)
    offset_lat = (uuid4().int % 900) / 1_000_000
    offset_lng = (uuid4().int % 900) / 1_000_000
    points = (
        f"{10.4236 + offset_lat:.6f},{-75.5478 + offset_lng:.6f};"
        f"{10.4236 + offset_lat / 2:.6f},{-75.5478 + offset_lng / 2:.6f}"
    )

    durations = []
    for _ in range(50):
        started = perf_counter()
        response = client.get(
            "/matching/suggestions",
            params={
                "direction": "to_campus",
                "points": points,
                "date": str(colombia_today()),
                "time": "07:00 AM",
            },
            headers={"Authorization": f"Bearer {passenger_token}"},
        )
        durations.append(perf_counter() - started)

        assert response.status_code == 200
        suggestions = response.json()
        matching_trip = next(item for item in suggestions if item["trip_id"] == trip.id)
        assert matching_trip["degraded"] is True

    p95 = sorted(durations)[ceil(len(durations) * 0.95) - 1]
    assert route_client.get.call_count == 50
    assert p95 < 3.99
    print(
        "GET /matching/suggestions con timeout OSRM: "
        f"N=50, HTTP 500=0, respuestas contractuales=100%, p95={p95:.4f}s"
    )
