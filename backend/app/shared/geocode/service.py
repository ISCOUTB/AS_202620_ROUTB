"""Servicio de geocodificación para ROUTB.

Flujo:
1. Normaliza la consulta.
2. Busca en ``geocode_cache`` (TTL = RETENTION_CACHE_DAYS días).
3. Si no hay caché, llama a Photon (``PHOTON_BASE_URL``).
4. Si Photon falla, llama a Nominatim como respaldo (máx. 1 req/s).
5. Persiste el resultado en la caché (upsert).

La autenticación y autorización (consentimiento) las verifica el router;
este servicio solo se ocupa de la geocodificación.
"""

from __future__ import annotations

import json
import logging
import re
import threading
import time
from typing import Any

import httpx
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.config import settings

logger = logging.getLogger(__name__)


class GeocodeUnavailable(RuntimeError):
    """Photon y Nominatim no pudieron atender la búsqueda."""

# Limitador global para Nominatim (1 req/s)
_nominatim_lock = threading.Lock()
_nominatim_last_call: float = 0.0
_NOMINATIM_MIN_INTERVAL = 1.05  # segundos


def _normalize_query(q: str) -> str:
    """Elimina espacios extra y convierte a minúsculas para usar como clave de caché."""
    return re.sub(r"\s+", " ", q.strip().lower())


def _cache_get(db: Session, key: str) -> list[dict[str, Any]] | None:
    """Devuelve los resultados del caché si no han expirado."""
    row = db.execute(
        text(
            "SELECT response FROM geocode_cache "
            "WHERE query = :q "
            "AND created_at > NOW() - (:days * INTERVAL '1 day')"
        ).bindparams(q=key, days=settings.RETENTION_CACHE_DAYS)
    ).fetchone()
    if row:
        return row[0]
    return None


def _cache_put(db: Session, key: str, results: list[dict[str, Any]]) -> None:
    """Guarda o actualiza los resultados en caché."""
    db.execute(
        text(
            "INSERT INTO geocode_cache (query, response) VALUES (:q, :r) "
            "ON CONFLICT (query) DO UPDATE "
            "SET response = EXCLUDED.response, created_at = NOW()"
        ).bindparams(q=key, r=json.dumps(results))
    )
    db.commit()


def _bbox_normalizado() -> str | None:
    """Devuelve el bbox como 'lon_min,lat_min,lon_max,lat_max', o None si no hay.

    Usa el mismo parser que el resto de la aplicación para aceptar también el
    formato con corchetes que documenta ``.env.example``: Nominatim responde 400
    si el ``viewbox`` lleva corchetes, y en Photon los corchetes rompen la
    conversión a número y el sesgo geográfico se perdía en silencio.
    """
    raw = settings.GEOCODE_BBOX
    if not raw or not raw.strip():
        return None
    lon_min, lat_min, lon_max, lat_max = settings.parse_geocode_bbox(raw)
    return f"{lon_min},{lat_min},{lon_max},{lat_max}"


def _call_photon(q: str) -> list[dict[str, Any]] | None:
    """Llama a Photon y devuelve lista de resultados normalizados, o None si falla."""
    base_url = settings.PHOTON_BASE_URL.rstrip("/")
    # Photon solo admite ``default``, ``de``, ``en`` y ``fr`` en ``lang``; con
    # ``lang=es`` responde 400 y toda búsqueda acababa cayendo al respaldo de
    # Nominatim. Sin ``lang`` se usan los nombres locales de OpenStreetMap, que
    # para Cartagena ya vienen en español.
    params: dict[str, Any] = {"q": q, "limit": 5}

    # Sesgo hacia el bounding box de Cartagena
    bbox = _bbox_normalizado()
    if bbox is not None:
        lon_min, lat_min, lon_max, lat_max = (float(p) for p in bbox.split(","))
        # Photon acepta location_bias_scale + lon/lat del centro del bbox
        params["lon"] = (lon_min + lon_max) / 2
        params["lat"] = (lat_min + lat_max) / 2

    try:
        with httpx.Client(
            timeout=settings.ROUTING_TIMEOUT_SECONDS,
            # Photon responde 403 al User-Agent por defecto de httpx, así que
            # hay que identificarse igual que con Nominatim.
            headers={"User-Agent": settings.NOMINATIM_USER_AGENT},
        ) as client:
            resp = client.get(f"{base_url}/api", params=params)
            resp.raise_for_status()
            data = resp.json()
    except Exception as exc:
        logger.warning("Photon no disponible: %s", exc)
        return None

    results = []
    for feature in data.get("features", []):
        props = feature.get("properties", {})
        geom = feature.get("geometry", {})
        coords = geom.get("coordinates", [None, None])
        results.append(
            {
                "lat": coords[1],
                "lng": coords[0],
                "display_name": ", ".join(
                    filter(
                        None,
                        [
                            props.get("name"),
                            props.get("street"),
                            props.get("housenumber"),
                            props.get("city"),
                            props.get("state"),
                            props.get("country"),
                        ],
                    )
                ),
                "source": "photon",
            }
        )
    return results


def _call_nominatim(q: str) -> list[dict[str, Any]] | None:
    """Llama a Nominatim respetando 1 req/s; None indica un fallo del proveedor."""
    global _nominatim_last_call
    with _nominatim_lock:
        elapsed = time.monotonic() - _nominatim_last_call
        if elapsed < _NOMINATIM_MIN_INTERVAL:
            time.sleep(_NOMINATIM_MIN_INTERVAL - elapsed)
        _nominatim_last_call = time.monotonic()

    base_url = settings.NOMINATIM_BASE_URL.rstrip("/")
    params: dict[str, Any] = {
        "q": q,
        "format": "jsonv2",
        "limit": 5,
        "addressdetails": 1,
        "accept-language": "es",
    }
    try:
        bbox = _bbox_normalizado()
        if bbox is not None:
            params["viewbox"] = bbox
    except (ValueError, AttributeError):
        pass

    try:
        with httpx.Client(
            timeout=settings.ROUTING_TIMEOUT_SECONDS,
            headers={"User-Agent": settings.NOMINATIM_USER_AGENT},
        ) as client:
            resp = client.get(f"{base_url}/search", params=params)
            resp.raise_for_status()
            data = resp.json()
    except Exception as exc:
        logger.warning("Nominatim no disponible: %s", exc)
        return None

    return [
        {
            "lat": float(item["lat"]),
            "lng": float(item["lon"]),
            "display_name": item.get("display_name", ""),
            "source": "nominatim",
        }
        for item in data
    ]


def geocode(db: Session, q: str) -> list[dict[str, Any]]:
    """Busca coordenadas para una dirección.

    Args:
        db: sesión de base de datos.
        q: texto libre de dirección.

    Returns:
        Lista de resultados con ``lat``, ``lng`` y ``display_name``.
    """
    key = _normalize_query(q)

    # 1. Intentar caché
    cached = _cache_get(db, key)
    if cached is not None:
        return cached

    # 2. Photon
    results = _call_photon(q)

    # 3. Respaldo Nominatim
    if results is None:
        results = _call_nominatim(q)

    if results is None:
        raise GeocodeUnavailable("Photon y Nominatim no están disponibles")

    # 4. Persistir en caché
    if results:
        _cache_put(db, key, results)

    return results or []
