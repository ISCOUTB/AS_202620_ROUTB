"""Pruebas unitarias del servicio de routing.

Cubre: caché, llamada a OSRM, timeout/fallo y respaldo geodésico.
Todo con mocks; sin llamadas reales a OSRM.
"""

from __future__ import annotations

import uuid
from unittest.mock import MagicMock, patch

import httpx
import pytest

from sqlalchemy import text

from app.core.database import SessionLocal
from app.shared.routing.service import (
    _cache_get,
    _cache_put,
    _call_osrm,
    _geodesic_fallback,
    _haversine_m,
    calculate_route,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_COORDS = [(10.371078, -75.466261), (10.40, -75.50)]  # campus UTB → punto ficticio


def _make_db(cached=None):
    db = MagicMock()
    db.execute.return_value.fetchone.return_value = (cached,) if cached is not None else None
    return db


# ---------------------------------------------------------------------------
# Tests auxiliares
# ---------------------------------------------------------------------------

def test_haversine_m_known_distance():
    """~2,9 km entre dos puntos con diferencia de ~0,02 grados lat/lng."""
    d = _haversine_m(10.42, -75.55, 10.40, -75.53)
    assert 2_000 < d < 4_000


def test_geodesic_fallback_structure():
    result = _geodesic_fallback(_COORDS)
    assert result["degraded"] is True
    assert result["source"] == "fallback"
    assert result["distance_m"] > 0
    assert result["duration_s"] > 0
    assert len(result["geometry"]) == 2  # dos puntos de línea recta


# ---------------------------------------------------------------------------
# Tests de caché
# ---------------------------------------------------------------------------

def test_calculate_route_returns_cached():
    cached = {
        "distance_m": 3500,
        "duration_s": 420,
        "geometry": [[-75.55, 10.42], [-75.50, 10.40]],
        "degraded": False,
        "source": "osrm",
    }
    db = _make_db(cached=cached)

    with patch("app.shared.routing.service._call_osrm") as mock_osrm:
        result = calculate_route(db, _COORDS)

    mock_osrm.assert_not_called()
    assert result["distance_m"] == 3500


# ---------------------------------------------------------------------------
# Tests de OSRM
# ---------------------------------------------------------------------------

def test_calculate_route_calls_osrm_when_no_cache():
    db = _make_db(cached=None)
    osrm_result = {
        "distance_m": 4000,
        "duration_s": 500,
        "geometry": [[-75.55, 10.42], [-75.50, 10.40]],
        "degraded": False,
        "source": "osrm",
    }

    with (
        patch("app.shared.routing.service._call_osrm", return_value=osrm_result),
        patch("app.shared.routing.service._cache_put"),
    ):
        result = calculate_route(db, _COORDS)

    assert result["source"] == "osrm"
    assert result["distance_m"] == 4000


def test_calculate_route_falls_back_when_osrm_fails():
    db = _make_db(cached=None)

    with (
        patch("app.shared.routing.service._call_osrm", return_value=None),
        patch("app.shared.routing.service._cache_put") as mock_cache_put,
    ):
        result = calculate_route(db, _COORDS)

    assert result["source"] == "fallback"
    assert result["degraded"] is True
    mock_cache_put.assert_not_called()


def test_call_osrm_uses_configured_timeout(monkeypatch):
    response = MagicMock()
    response.json.return_value = {
        "code": "Ok",
        "routes": [{
            "distance": 1200,
            "duration": 180,
            "geometry": {"coordinates": [[-75.4, 10.3], [-75.5, 10.4]]},
        }],
    }
    client = MagicMock()
    client.__enter__.return_value.get.return_value = response
    client_context = MagicMock(return_value=client)
    monkeypatch.setattr("app.shared.routing.service.httpx.Client", client_context)
    monkeypatch.setattr("app.shared.routing.service.settings.ROUTING_TIMEOUT_SECONDS", 1.25)
    monkeypatch.setattr("app.shared.routing.service.time.sleep", lambda _: None)
    monkeypatch.setattr("app.shared.routing.service._osrm_last_call", 0.0)

    result = _call_osrm(_COORDS)

    client_context.assert_called_once_with(timeout=1.25)
    assert result["degraded"] is False


# ---------------------------------------------------------------------------
# Tests de validación
# ---------------------------------------------------------------------------

def test_calculate_route_raises_with_single_coord():
    db = _make_db()
    with pytest.raises(ValueError, match="al menos dos"):
        calculate_route(db, [(10.42, -75.55)])


def test_route_cache_query_and_ttl_with_postgres():
    """La consulta parametrizada lee entradas vigentes y descarta las vencidas."""
    db = SessionLocal()
    key = f"routing-test-{uuid.uuid4()}"
    expected = {"distance_m": 123, "degraded": False, "source": "osrm"}
    degraded = {"distance_m": 321, "degraded": True, "source": "fallback"}
    try:
        _cache_put(db, key, expected)
        assert _cache_get(db, key) == expected

        _cache_put(db, key, degraded)
        assert _cache_get(db, key) is None

        _cache_put(db, key, expected)

        db.execute(
            text("UPDATE route_cache SET created_at = NOW() - INTERVAL '25 hours' WHERE cache_key = :k"),
            {"k": key},
        )
        db.commit()
        assert _cache_get(db, key) is None
    finally:
        db.execute(text("DELETE FROM route_cache WHERE cache_key = :k"), {"k": key})
        db.commit()
        db.close()


# ---------------------------------------------------------------------------
# Tests de timeout real (ADR 0014)
# ---------------------------------------------------------------------------

def test_call_osrm_timeout_falls_back_degraded_without_cache(monkeypatch):
    """Timeout de OSRM → respaldo geodésico sin persistirlo en caché."""
    db = _make_db(cached=None)

    client = MagicMock()
    client.__enter__.return_value.get.side_effect = httpx.TimeoutException("timeout")
    monkeypatch.setattr(
        "app.shared.routing.service.httpx.Client", MagicMock(return_value=client)
    )
    monkeypatch.setattr("app.shared.routing.service.time.sleep", lambda _: None)
    monkeypatch.setattr("app.shared.routing.service._osrm_last_call", 0.0)

    with patch(
        "app.shared.routing.service._cache_put"
    ) as mock_cache_put:
        result = calculate_route(db, _COORDS)

    assert result["degraded"] is True
    assert result["source"] == "fallback"
    mock_cache_put.assert_not_called()
