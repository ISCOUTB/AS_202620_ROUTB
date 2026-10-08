"""Servicio de routing para ROUTB.

Calcula rutas entre una serie de coordenadas usando OSRM.
Implementa:
- Caché en ``route_cache`` (TTL 24 h, llave = SHA-256 de coordenadas a 5 decimales).
- Limitador interno de 1 req/s al servidor público de OSRM.
- Respaldo geodésico cuando OSRM no responde (distancia × 1.3, velocidad 25 km/h).

Uso::

    from app.shared.routing.service import calculate_route

    result = calculate_route(db, [(lat1, lng1), (lat2, lng2)])
    # result = {
    #     "distance_m": 3500,
    #     "duration_s": 420,
    #     "geometry": [[lng, lat], ...],   # lista de coordenadas [lng, lat]
    #     "degraded": False,
    #     "source": "osrm"
    # }
"""

from __future__ import annotations

import hashlib
import json
import logging
import math
import threading
import time
from typing import Any

import httpx
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.config import settings

logger = logging.getLogger(__name__)

# Limitador global OSRM (1 req/s para servidor público)
_osrm_lock = threading.Lock()
_osrm_last_call: float = 0.0
_OSRM_MIN_INTERVAL = 1.05  # segundos
_CACHE_TTL_HOURS = 24


def _coords_key(coords: list[tuple[float, float]]) -> str:
    """SHA-256 de las coordenadas redondeadas a 5 decimales."""
    canonical = ";".join(f"{round(lat, 5)},{round(lng, 5)}" for lat, lng in coords)
    return hashlib.sha256(canonical.encode()).hexdigest()


def _cache_get(db: Session, key: str) -> dict[str, Any] | None:
    row = db.execute(
        text(
            "SELECT response FROM route_cache "
            "WHERE cache_key = :k "
            "AND created_at > NOW() - INTERVAL ':h hours'"
        ).bindparams(k=key, h=_CACHE_TTL_HOURS)
    ).fetchone()
    if row:
        return row[0]
    return None


def _cache_put(db: Session, key: str, result: dict[str, Any]) -> None:
    db.execute(
        text(
            "INSERT INTO route_cache (cache_key, response) VALUES (:k, :r) "
            "ON CONFLICT (cache_key) DO UPDATE "
            "SET response = EXCLUDED.response, created_at = NOW()"
        ).bindparams(k=key, r=json.dumps(result))
    )
    db.commit()


def _haversine_m(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Distancia en metros entre dos puntos (fórmula de Haversine)."""
    R = 6_371_000
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lng2 - lng1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def _geodesic_fallback(coords: list[tuple[float, float]]) -> dict[str, Any]:
    """Cálculo de respaldo: distancia geodésica × 1.3, velocidad 25 km/h."""
    total_m = 0.0
    for i in range(len(coords) - 1):
        total_m += _haversine_m(coords[i][0], coords[i][1], coords[i + 1][0], coords[i + 1][1])
    road_m = total_m * 1.3
    duration_s = int(road_m / (25_000 / 3600))
    # Geometría: línea recta entre los puntos (lng, lat) para GeoJSON
    geometry = [[lng, lat] for lat, lng in coords]
    return {
        "distance_m": int(road_m),
        "duration_s": duration_s,
        "geometry": geometry,
        "degraded": True,
        "source": "fallback",
    }


def _call_osrm(coords: list[tuple[float, float]]) -> dict[str, Any] | None:
    """Llama al servidor OSRM respetando 1 req/s."""
    global _osrm_last_call
    with _osrm_lock:
        elapsed = time.monotonic() - _osrm_last_call
        if elapsed < _OSRM_MIN_INTERVAL:
            time.sleep(_OSRM_MIN_INTERVAL - elapsed)
        _osrm_last_call = time.monotonic()

    base_url = settings.ROUTING_BASE_URL.rstrip("/")
    # OSRM espera coordenadas en formato lng,lat;lng,lat
    coord_str = ";".join(f"{lng},{lat}" for lat, lng in coords)
    url = f"{base_url}/route/v1/driving/{coord_str}"
    params = {"overview": "full", "geometries": "geojson", "steps": "false"}

    try:
        with httpx.Client(timeout=3.0) as client:
            resp = client.get(url, params=params)
            resp.raise_for_status()
            data = resp.json()
    except Exception as exc:
        logger.warning("OSRM no disponible: %s", exc)
        return None

    if data.get("code") != "Ok" or not data.get("routes"):
        logger.warning("OSRM devolvió respuesta vacía: %s", data.get("code"))
        return None

    route = data["routes"][0]
    geometry = route["geometry"]["coordinates"]  # ya es [[lng, lat], ...]
    return {
        "distance_m": int(route["distance"]),
        "duration_s": int(route["duration"]),
        "geometry": geometry,
        "degraded": False,
        "source": "osrm",
    }


def calculate_route(
    db: Session,
    coords: list[tuple[float, float]],
) -> dict[str, Any]:
    """Calcula la ruta entre una lista de puntos ``(lat, lng)``.

    Intenta primero OSRM con caché y, en caso de fallo, devuelve la ruta
    de respaldo geodésica marcada con ``degraded=True``.

    Args:
        db: sesión de base de datos.
        coords: lista de tuplas ``(lat, lng)`` de al menos dos puntos.

    Returns:
        Diccionario con ``distance_m``, ``duration_s``, ``geometry``,
        ``degraded`` y ``source``.
    """
    if len(coords) < 2:
        raise ValueError("Se necesitan al menos dos coordenadas para calcular una ruta.")

    key = _coords_key(coords)

    # 1. Caché
    cached = _cache_get(db, key)
    if cached is not None:
        return cached

    # 2. OSRM
    result = _call_osrm(coords)

    # 3. Respaldo geodésico
    if result is None:
        result = _geodesic_fallback(coords)

    # 4. Persistir en caché
    _cache_put(db, key, result)

    return result
