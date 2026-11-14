"""Mide la latencia de un endpoint HTTP de ROUTB (Semana 14).

El script ejecuta un calentamiento, varias rondas de peticiones secuenciales y
calcula mínimo, promedio, p95 y máximo por ronda. Guarda el resultado crudo en
JSON para que otra persona pueda contrastarlo con el umbral de arc42 sección 10.

Uso recomendado desde la raíz del repositorio:

    backend/.venv/Scripts/python.exe scripts/medir_rendimiento.py ^
        --url http://127.0.0.1:8014/trips/ ^
        --warmup-url http://127.0.0.1:8014/health ^
        --label local ^
        --output docs/evidencia/medicion-semana14-local.json

No requiere autenticación para ``GET /trips/``. Si el endpoint devuelve un
código distinto de 200, la ronda se aborta para no mezclar errores con tiempos.

Por seguridad, solo se miden URLs HTTP(S) cuyo host esté autorizado (por
defecto, loopback) mediante ``--allow-host``, y el JSON de salida se escribe
únicamente como archivo directo dentro de ``docs/evidencia/`` (sin
subcarpetas). Las URLs con credenciales embebidas se rechazan.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import platform
import re
import statistics
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

import httpx

REPO_ROOT = Path(__file__).resolve().parent.parent
EVIDENCE_DIR = REPO_ROOT / "docs" / "evidencia"
DEFAULT_ALLOWED_HOSTS = frozenset({"127.0.0.1", "localhost", "::1"})
_OUTPUT_NAME_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]*")


def _validate_target(
    raw_url: str, allowed_hosts: set[str] | frozenset[str]
) -> httpx.URL:
    """Valida esquema, credenciales y host antes de exponer la URL a httpx."""
    try:
        target = httpx.URL(raw_url)
    except (httpx.InvalidURL, ValueError) as exc:
        raise ValueError(f"URL inválida: {raw_url!r}") from exc

    if target.scheme not in ("http", "https"):
        raise ValueError(f"La URL debe usar http o https: {raw_url!r}")
    if not target.host:
        raise ValueError(f"La URL no incluye un host: {raw_url!r}")
    if target.username or target.password:
        raise ValueError("La URL no puede incluir credenciales")

    host = target.host.rstrip(".").lower()
    if host not in allowed_hosts:
        raise ValueError(
            f"Host no autorizado: {host!r}. Usa --allow-host para autorizarlo."
        )
    return target


def _validate_output_path(raw_path: str) -> Path:
    """Confina la escritura a un archivo directo dentro de docs/evidencia."""
    evidence_dir = EVIDENCE_DIR.resolve()
    candidate = Path(raw_path)
    if not candidate.is_absolute():
        candidate = REPO_ROOT / candidate

    resolved = candidate.resolve()
    if resolved == evidence_dir or not resolved.is_relative_to(evidence_dir):
        raise ValueError(
            f"--output debe apuntar a un archivo dentro de {evidence_dir}"
        )
    if resolved.parent != evidence_dir:
        raise ValueError(
            f"--output debe ser un archivo directamente dentro de {evidence_dir}"
        )
    if _OUTPUT_NAME_RE.fullmatch(resolved.name) is None:
        raise ValueError(
            "--output debe tener un nombre de archivo simple: letras, "
            "números, punto, guion o guion bajo"
        )
    return resolved


def _percentile(sorted_values: list[float], percentile: float) -> float:
    """Percentil por rango más cercano, igual que el procedimiento existente."""
    if not sorted_values:
        raise ValueError("No hay valores para calcular el percentil")
    index = math.ceil(len(sorted_values) * percentile) - 1
    index = max(0, min(index, len(sorted_values) - 1))
    return sorted_values[index]


def _round_stats(times_ms: list[float]) -> dict[str, float]:
    ordered = sorted(times_ms)
    return {
        "n": len(ordered),
        "min_ms": round(ordered[0], 2),
        "avg_ms": round(statistics.fmean(ordered), 2),
        "p95_ms": round(_percentile(ordered, 0.95), 2),
        "max_ms": round(ordered[-1], 2),
    }


def _measure_round(
    client: httpx.Client, url: httpx.URL, requests_count: int
) -> tuple[dict[str, float], dict[str, int], list[int]]:
    times_ms: list[float] = []
    status_codes: dict[str, int] = {}
    payload_items: list[int] = []

    for _ in range(requests_count):
        started = time.perf_counter_ns()
        response = client.get(url)
        elapsed_ms = (time.perf_counter_ns() - started) / 1_000_000
        status_codes[str(response.status_code)] = (
            status_codes.get(str(response.status_code), 0) + 1
        )
        if response.status_code != 200:
            raise RuntimeError(
                f"{url} respondió {response.status_code}; se esperaba 200"
            )
        times_ms.append(elapsed_ms)
        try:
            payload = response.json()
        except ValueError:
            continue
        if isinstance(payload, list):
            payload_items.append(len(payload))

    return _round_stats(times_ms), status_codes, payload_items


def _environment_snapshot() -> dict[str, object]:
    return {
        "platform": platform.platform(),
        "python": platform.python_version(),
        "httpx": httpx.__version__,
        "processor": platform.processor() or "no disponible",
        "cpu_count": None,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", required=True, help="Endpoint que se mide")
    parser.add_argument(
        "--warmup-url",
        default=None,
        help="Endpoint de calentamiento (por defecto /health del mismo host)",
    )
    parser.add_argument("--requests", type=int, default=100, help="Peticiones por ronda")
    parser.add_argument("--repetitions", type=int, default=3, help="Número de rondas")
    parser.add_argument(
        "--warmup-seconds", type=float, default=5.0, help="Espera tras calentar"
    )
    parser.add_argument(
        "--threshold-ms", type=float, default=3990.0, help="Umbral p95 en milisegundos"
    )
    parser.add_argument("--timeout", type=float, default=35.0, help="Timeout por petición")
    parser.add_argument("--label", required=True, help="Nombre del entorno medido")
    parser.add_argument(
        "--output",
        required=True,
        help=(
            "Archivo JSON directamente dentro de docs/evidencia donde se "
            "guardan los resultados"
        ),
    )
    parser.add_argument(
        "--allow-host",
        action="append",
        default=None,
        metavar="HOST",
        help=(
            "Host autorizado para las peticiones (repetible). Por defecto: "
            "localhost, 127.0.0.1 y ::1"
        ),
    )
    args = parser.parse_args()

    if args.requests < 1 or args.repetitions < 1:
        parser.error("--requests y --repetitions deben ser mayores que cero")

    allowed_hosts = set(DEFAULT_ALLOWED_HOSTS)
    for host in args.allow_host or []:
        normalized = host.strip().rstrip(".").lower()
        if not normalized:
            parser.error("--allow-host no puede estar vacío")
        allowed_hosts.add(normalized)

    warmup_url = args.warmup_url
    if warmup_url is None:
        base = args.url.split("/trips", 1)[0]
        warmup_url = f"{base}/health"

    try:
        target_url = _validate_target(args.url, allowed_hosts)
        warmup_target_url = _validate_target(warmup_url, allowed_hosts)
        _validate_output_path(args.output)
        # Se reconstruye la ruta del sink con la carpeta confiable y
        # ``os.path.basename``, que Sonar reconoce como saneador de rutas
        # (S8707). ``Path.name`` no bastaba para su motor de taint.
        output_name = os.path.basename(args.output)
        if _OUTPUT_NAME_RE.fullmatch(output_name) is None:
            raise ValueError(
                "--output debe tener un nombre de archivo simple: letras, "
                "números, punto, guion o guion bajo"
            )
        safe_output_path = EVIDENCE_DIR.resolve() / output_name
    except ValueError as exc:
        parser.error(str(exc))

    environment = _environment_snapshot()
    environment["cpu_count"] = os.cpu_count()

    rounds: list[dict[str, object]] = []
    started_at = datetime.now(timezone.utc)

    with httpx.Client(timeout=args.timeout, follow_redirects=False) as client:
        warmup_response = client.get(warmup_target_url)
        if warmup_response.status_code != 200:
            raise RuntimeError(
                f"El calentamiento {warmup_target_url} respondió "
                f"{warmup_response.status_code}; se esperaba 200"
            )
        time.sleep(args.warmup_seconds)

        for number in range(1, args.repetitions + 1):
            stats, status_codes, payload_items = _measure_round(
                client, target_url, args.requests
            )
            rounds.append(
                {
                    "round": number,
                    **stats,
                    "status_codes": status_codes,
                    "payload_items": payload_items,
                }
            )
            print(
                f"Ronda {number}: n={stats['n']} "
                f"p95={stats['p95_ms']} ms max={stats['max_ms']} ms"
            )

    p95_values = [float(item["p95_ms"]) for item in rounds]
    worst_p95 = max(p95_values)
    conclusion = "CUMPLE" if worst_p95 < args.threshold_ms else "NO CUMPLE"
    finished_at = datetime.now(timezone.utc)

    result = {
        "label": args.label,
        "url": str(target_url),
        "warmup_url": str(warmup_target_url),
        "started_at_utc": started_at.isoformat(),
        "finished_at_utc": finished_at.isoformat(),
        "duration_s": round((finished_at - started_at).total_seconds(), 2),
        "environment": environment,
        "requests_per_round": args.requests,
        "repetitions": args.repetitions,
        "warmup_seconds": args.warmup_seconds,
        "threshold_ms": args.threshold_ms,
        "rounds": rounds,
        "summary": {
            "p95_ms_per_round": p95_values,
            "worst_p95_ms": worst_p95,
            "conclusion": conclusion,
        },
    }

    safe_output_path.parent.mkdir(parents=True, exist_ok=True)
    safe_output_path.write_text(
        json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )

    print()
    print("| Ronda | N | Mínimo | Promedio | p95 | Máximo |")
    print("|---|---:|---:|---:|---:|---:|")
    for item in rounds:
        print(
            f"| {item['round']} | {item['n']} | {item['min_ms']} ms | "
            f"{item['avg_ms']} ms | **{item['p95_ms']} ms** | {item['max_ms']} ms |"
        )
    print()
    print(f"p95 más alto de las rondas: {worst_p95} ms")
    print(f"Umbral: {args.threshold_ms} ms")
    print(f"Resultado: {conclusion}")
    print(f"Resultados crudos: {safe_output_path}")

    return 0 if conclusion == "CUMPLE" else 1


if __name__ == "__main__":
    sys.exit(main())
