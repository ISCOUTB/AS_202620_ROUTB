"""Pruebas unitarias del servicio de routing.

Cubre: caché, llamada a OSRM, timeout/fallo y respaldo geodésico.
Todo con mocks; sin llamadas reales a OSRM.
"""

from __future__ import annotations

import json
from unittest.mock import MagicMock, patch

import pytest

from app.shared.routing.service import _geodesic_fallback, _haversine_m, calculate_route


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_COORDS = [(10.4238, -75.5510), (10.40, -75.50)]  # campus UTB → punto ficticio


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
        patch("app.shared.routing.service._cache_put"),
    ):
        result = calculate_route(db, _COORDS)

    assert result["source"] == "fallback"
    assert result["degraded"] is True


# ---------------------------------------------------------------------------
# Tests de validación
# ---------------------------------------------------------------------------

def test_calculate_route_raises_with_single_coord():
    db = _make_db()
    with pytest.raises(ValueError, match="al menos dos"):
        calculate_route(db, [(10.42, -75.55)])
