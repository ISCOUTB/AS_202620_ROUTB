"""Pruebas unitarias del servicio de geocodificación.

Estrategia: todos los tests usan ``httpx.MockTransport`` para evitar
llamadas reales a Photon o Nominatim.
"""

from __future__ import annotations

from datetime import datetime
import json
import os
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


# ---------------------------------------------------------------------------
# Tests de timeout real (ADR 0014)
# ---------------------------------------------------------------------------

def test_geocode_timeout_uses_configured_timeout(monkeypatch):
    """Photon y Nominatim deben usar ROUTING_TIMEOUT_SECONDS (ADR 0014)."""
    db = _make_db(cached=None)
    monkeypatch.setattr(
        "app.shared.geocode.service.settings.ROUTING_TIMEOUT_SECONDS", 1.4
    )
    seen_timeouts: list[float] = []

    def fake_client(*args, **kwargs):
        seen_timeouts.append(kwargs.get("timeout"))
        instance = MagicMock()
        instance.__enter__ = MagicMock(return_value=instance)
        instance.__exit__ = MagicMock(return_value=False)
        instance.get.side_effect = httpx.TimeoutException("timeout")
        return instance

    monkeypatch.setattr("app.shared.geocode.service.httpx.Client", fake_client)
    monkeypatch.setattr("app.shared.geocode.service.time.sleep", lambda _: None)

    with pytest.raises(GeocodeUnavailable):
        geocode(db, "Timeout Cartagena")

    assert seen_timeouts == [1.4, 1.4]


def test_geocode_timeout_photon_falls_back_to_nominatim(monkeypatch):
    """Timeout real en Photon → se intenta Nominatim y se usa su respuesta."""
    db = _make_db(cached=None)
    monkeypatch.setattr("app.shared.geocode.service.time.sleep", lambda _: None)

    def fake_client(*args, **kwargs):
        instance = MagicMock()
        instance.__enter__ = MagicMock(return_value=instance)
        instance.__exit__ = MagicMock(return_value=False)

        def fake_get(url, params=None, **kw):
            if "photon" in str(url):
                raise httpx.TimeoutException("photon timeout")
            resp = MagicMock()
            resp.raise_for_status.return_value = None
            resp.json.return_value = [
                {
                    "lat": "10.40",
                    "lon": "-75.50",
                    "display_name": "Centro, Cartagena",
                }
            ]
            return resp

        instance.get = fake_get
        return instance

    monkeypatch.setattr("app.shared.geocode.service.httpx.Client", fake_client)

    with patch("app.shared.geocode.service._cache_put"):
        result = geocode(db, "Timeout Cartagena")

    assert result[0]["source"] == "nominatim"


# ---------------------------------------------------------------------------
# Contrato del request a Photon
# ---------------------------------------------------------------------------

# Photon solo admite estos valores en ``lang``; cualquier otro responde 400.
_PHOTON_LANGS_SOPORTADOS = {"default", "de", "en", "fr"}


def _capturar_peticion_a_photon(monkeypatch) -> dict:
    """Intercepta la petición HTTP a Photon y devuelve params y headers."""
    capturado: dict = {"params": {}, "headers": {}}

    def fake_client(*args, **kwargs):
        capturado["headers"] = dict(kwargs.get("headers") or {})
        instance = MagicMock()
        instance.__enter__ = MagicMock(return_value=instance)
        instance.__exit__ = MagicMock(return_value=False)

        def fake_get(url, params=None, **kw):
            capturado["params"] = dict(params or {})
            resp = MagicMock()
            resp.raise_for_status.return_value = None
            resp.json.return_value = {"type": "FeatureCollection", "features": []}
            return resp

        instance.get = fake_get
        return instance

    monkeypatch.setattr("app.shared.geocode.service.httpx.Client", fake_client)
    return capturado


def test_photon_no_envia_lang_no_soportado(monkeypatch):
    """El request a Photon no puede llevar un ``lang`` que Photon rechace.

    Photon responde 400 a ``lang=es`` —solo admite default/de/en/fr— y ese 400
    hacía que toda búsqueda cayera al respaldo de Nominatim sin que ninguna
    prueba lo notara, porque el transporte HTTP está simulado.
    """
    from app.shared.geocode.service import _call_photon

    capturado = _capturar_peticion_a_photon(monkeypatch)
    _call_photon("Manga")

    lang = capturado["params"].get("lang")
    assert lang is None or lang in _PHOTON_LANGS_SOPORTADOS


def test_photon_se_identifica_con_su_propio_user_agent(monkeypatch):
    """Photon responde 403 al User-Agent por defecto de httpx.

    Sin cabecera propia el proveedor bloquea la petición y la búsqueda vuelve a
    depender del respaldo, igual que con el ``lang`` inválido.
    """
    from app.shared.geocode.service import _call_photon

    capturado = _capturar_peticion_a_photon(monkeypatch)
    _call_photon("Manga")

    headers = {clave.lower(): valor for clave, valor in capturado["headers"].items()}
    user_agent = headers.get("user-agent", "")
    assert user_agent, "Photon exige que el cliente se identifique"
    assert "httpx" not in user_agent.lower(), "ese User-Agent recibe 403"


def test_photon_conserva_el_sesgo_geografico(monkeypatch):
    """Sin ``lang`` el sesgo por el centro del bbox debe seguir intacto."""
    from app.shared.geocode.service import _call_photon

    capturado = _capturar_peticion_a_photon(monkeypatch)
    _call_photon("Manga")

    assert capturado["params"]["q"] == "Manga"
    assert capturado["params"]["limit"] == 5
    assert "lat" in capturado["params"] and "lon" in capturado["params"]


# ---------------------------------------------------------------------------
# Formato del bounding box
# ---------------------------------------------------------------------------

# El .env.example documenta el formato con corchetes; `parse_geocode_bbox`
# acepta los dos, así que los proveedores deben recibir siempre el normalizado.
_BBOX_SIN_CORCHETES = "-75.6,10.3,-75.45,10.5"
_BBOX_CON_CORCHETES = "[-75.6,10.3,-75.45,10.5]"


def _capturar_params_hacia_nominatim(monkeypatch) -> dict:
    """Intercepta la petición HTTP a Nominatim y devuelve sus params."""
    capturado: dict = {}

    def fake_client(*args, **kwargs):
        instance = MagicMock()
        instance.__enter__ = MagicMock(return_value=instance)
        instance.__exit__ = MagicMock(return_value=False)

        def fake_get(url, params=None, **kw):
            capturado.update(params or {})
            resp = MagicMock()
            resp.raise_for_status.return_value = None
            resp.json.return_value = []
            return resp

        instance.get = fake_get
        return instance

    monkeypatch.setattr("app.shared.geocode.service.httpx.Client", fake_client)
    monkeypatch.setattr("app.shared.geocode.service.time.sleep", lambda _: None)
    return capturado


@pytest.mark.parametrize("crudo", [_BBOX_SIN_CORCHETES, _BBOX_CON_CORCHETES])
def test_nominatim_recibe_el_viewbox_sin_corchetes(monkeypatch, crudo):
    """Nominatim responde 400 si el ``viewbox`` lleva corchetes.

    El formato con corchetes es el que trae `.env.example`, así que el respaldo
    quedaba inservible en cualquier despliegue que lo copiara.
    """
    from app.shared.geocode.service import _call_nominatim

    monkeypatch.setattr("app.shared.geocode.service.settings.GEOCODE_BBOX", crudo)
    capturado = _capturar_params_hacia_nominatim(monkeypatch)
    _call_nominatim("Manga")

    assert capturado["viewbox"] == _BBOX_SIN_CORCHETES
    assert "[" not in capturado["viewbox"] and "]" not in capturado["viewbox"]


@pytest.mark.parametrize("crudo", [_BBOX_SIN_CORCHETES, _BBOX_CON_CORCHETES])
def test_photon_conserva_el_sesgo_con_el_bbox_entre_corchetes(monkeypatch, crudo):
    """Con corchetes, ``float('[-75.6')`` fallaba y el sesgo se perdía en silencio."""
    from app.shared.geocode.service import _call_photon

    monkeypatch.setattr("app.shared.geocode.service.settings.GEOCODE_BBOX", crudo)
    capturado = _capturar_peticion_a_photon(monkeypatch)
    _call_photon("Manga")

    assert isinstance(capturado["params"]["lat"], float)
    assert isinstance(capturado["params"]["lon"], float)


# ---------------------------------------------------------------------------
# Prueba externa (opt-in) contra el Photon real
# ---------------------------------------------------------------------------

@pytest.mark.external
@pytest.mark.skipif(
    os.getenv("RUN_EXTERNAL_TESTS") != "1",
    reason="Llama a Photon real; se activa con RUN_EXTERNAL_TESTS=1",
)
def test_photon_real_acepta_el_request():
    """Comprueba contra el proveedor real que el request ya no da 400.

    No se ejecuta por defecto para no meter la red en la suite ni en el CI.
    Uso: ``RUN_EXTERNAL_TESTS=1 pytest -q -m external``.
    """
    from app.shared.geocode.service import _call_photon

    resultado = _call_photon("Manga, Cartagena")

    assert resultado is not None, "Photon rechazó el request (revisa los parámetros)"
    assert resultado, "Photon respondió sin resultados para una consulta con coincidencias"
