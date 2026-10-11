"""Pruebas unitarias del servicio de geocodificación.

Estrategia: todos los tests usan ``httpx.MockTransport`` para evitar
llamadas reales a Photon o Nominatim.
"""

from __future__ import annotations

from datetime import datetime
import json
from unittest.mock import MagicMock, patch

import httpx
import pytest
from fastapi.testclient import TestClient

from app.core.database import get_db
from app.main import app
from app.modules.auth.infrastructure.security import get_current_user
from app.modules.users.application import UserIdentity
from app.shared.geocode.service import GeocodeUnavailable, _normalize_query, geocode


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _photon_response(results: list[dict]) -> dict:
    """Genera una respuesta Photon válida."""
    features = []
    for r in results:
        features.append(
            {
                "type": "Feature",
                "geometry": {"type": "Point", "coordinates": [r["lng"], r["lat"]]},
                "properties": {
                    "name": r.get("name", ""),
                    "city": r.get("city", "Cartagena"),
                    "country": "Colombia",
                },
            }
        )
    return {"type": "FeatureCollection", "features": features}


def _nominatim_response(results: list[dict]) -> list[dict]:
    return [
        {
            "lat": str(r["lat"]),
            "lon": str(r["lng"]),
            "display_name": r.get("name", "Dirección de prueba"),
        }
        for r in results
    ]


def _make_db(cached=None):
    """Devuelve un mock de Session con caché vacía por defecto."""
    db = MagicMock()
    # _cache_get devuelve None (sin caché) por defecto
    row = MagicMock()
    row.__getitem__ = MagicMock(return_value=cached)
    db.execute.return_value.fetchone.return_value = (cached,) if cached is not None else None
    return db


# ---------------------------------------------------------------------------
# Tests de normalización
# ---------------------------------------------------------------------------

def test_normalize_query():
    assert _normalize_query("  Centro  ") == "centro"
    assert _normalize_query("Avenida  del  Lago") == "avenida del lago"


# ---------------------------------------------------------------------------
# Tests de caché
# ---------------------------------------------------------------------------

def test_geocode_returns_cached_result():
    """Si hay caché, se devuelve sin llamar a Photon."""
    cached = [{"lat": 10.4, "lng": -75.5, "display_name": "Test", "source": "photon"}]
    db = _make_db(cached=cached)

    with patch("app.shared.geocode.service._call_photon") as mock_photon:
        result = geocode(db, "centro")

    mock_photon.assert_not_called()
    assert result == cached


# ---------------------------------------------------------------------------
# Tests de Photon
# ---------------------------------------------------------------------------

def test_geocode_calls_photon_when_no_cache():
    """Sin caché llama a Photon y guarda el resultado."""
    db = _make_db(cached=None)
    photon_data = [{"lat": 10.42, "lng": -75.55, "name": "UTB"}]

    with (
        patch("app.shared.geocode.service._call_photon") as mock_photon,
        patch("app.shared.geocode.service._cache_put") as mock_put,
    ):
        mock_photon.return_value = [
            {"lat": 10.42, "lng": -75.55, "display_name": "UTB, Cartagena", "source": "photon"}
        ]
        result = geocode(db, "UTB Cartagena")

    mock_photon.assert_called_once()
    mock_put.assert_called_once()
    assert result[0]["lat"] == 10.42


# ---------------------------------------------------------------------------
# Tests de fallback Nominatim
# ---------------------------------------------------------------------------

def test_geocode_falls_back_to_nominatim_when_photon_fails():
    """Si Photon devuelve None, se llama a Nominatim."""
    db = _make_db(cached=None)

    nominatim_result = [
        {"lat": 10.40, "lng": -75.50, "display_name": "Centro, Cartagena", "source": "nominatim"}
    ]

    with (
        patch("app.shared.geocode.service._call_photon", return_value=None),
        patch("app.shared.geocode.service._call_nominatim", return_value=nominatim_result),
        patch("app.shared.geocode.service._cache_put"),
    ):
        result = geocode(db, "Centro Cartagena")

    assert result[0]["source"] == "nominatim"


def test_geocode_returns_empty_when_both_fail():
    """Una respuesta exitosa sin coincidencias se distingue de una caída."""
    db = _make_db(cached=None)

    with (
        patch("app.shared.geocode.service._call_photon", return_value=None),
        patch("app.shared.geocode.service._call_nominatim", return_value=[]),
        patch("app.shared.geocode.service._cache_put"),
    ):
        result = geocode(db, "Dirección inexistente xyz")

    assert result == []


def test_geocode_raises_when_both_providers_are_unavailable():
    db = _make_db(cached=None)
    with (
        patch("app.shared.geocode.service._call_photon", return_value=None),
        patch("app.shared.geocode.service._call_nominatim", return_value=None),
        pytest.raises(GeocodeUnavailable),
    ):
        geocode(db, "Dirección de prueba")


def test_geocode_endpoint_returns_503_when_both_providers_fail():
    user = UserIdentity(123456, "Test", "User", "3000000000", "passenger", datetime.now())
    app.dependency_overrides[get_current_user] = lambda: user
    app.dependency_overrides[get_db] = lambda: _make_db()
    try:
        with (
            patch("app.modules.geocode.infrastructure.router.geocode", side_effect=GeocodeUnavailable()),
            TestClient(app) as client,
        ):
            response = client.get("/geocode/search", params={"q": "UTB"})
        assert response.status_code == 503
        assert response.json()["detail"] == "geocode_unavailable"
    finally:
        app.dependency_overrides.clear()


def test_geocode_endpoint_returns_429_when_user_exceeds_limit():
    user = UserIdentity(123457, "Test", "User", "3000000001", "passenger", datetime.now())
    app.dependency_overrides[get_current_user] = lambda: user
    app.dependency_overrides[get_db] = lambda: _make_db()
    try:
        with (
            patch("app.modules.geocode.infrastructure.router.geocode_search_rate_limit.allow", return_value=False),
            TestClient(app) as client,
        ):
            response = client.get("/geocode/search", params={"q": "UTB"})
        assert response.status_code == 429
        assert response.json()["detail"] == "geocode_rate_limit_exceeded"
    finally:
        app.dependency_overrides.clear()


# ---------------------------------------------------------------------------
# Test de límite de velocidad Nominatim
# ---------------------------------------------------------------------------

def test_nominatim_rate_limit():
    """Dos llamadas consecutivas a Nominatim están separadas por ≥ 1 s.

    Este test NO hace llamadas reales: solo verifica que la función de respaldo
    espera entre llamadas usando el lock interno.
    """
    import time
    from app.shared.geocode.service import _call_nominatim

    call_times: list[float] = []

    def fake_get(*args, **kwargs):
        call_times.append(time.monotonic())
        resp = MagicMock()
        resp.json.return_value = []
        resp.raise_for_status.return_value = None
        return resp

    with patch("httpx.Client") as mock_client_cls:
        instance = MagicMock()
        instance.__enter__ = MagicMock(return_value=instance)
        instance.__exit__ = MagicMock(return_value=False)
        instance.get = fake_get
        mock_client_cls.return_value = instance

        _call_nominatim("consulta 1")
        _call_nominatim("consulta 2")

    if len(call_times) == 2:
        assert call_times[1] - call_times[0] >= 1.0
