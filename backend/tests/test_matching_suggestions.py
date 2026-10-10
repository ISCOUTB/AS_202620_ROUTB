"""Pruebas del módulo de matching y sugerencias de viajes (Fase 2)."""

import json
from datetime import date, timedelta
from uuid import uuid4

import pytest
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
