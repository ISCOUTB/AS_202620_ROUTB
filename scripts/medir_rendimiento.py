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
"""

from __future__ import annotations

import argparse
import json
import math
import os
import platform
import statistics
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

import httpx


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
    client: httpx.Client, url: str, requests_count: int
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
        "--output", required=True, help="Archivo JSON donde se guardan los resultados"
    )
    args = parser.parse_args()

    if args.requests < 1 or args.repetitions < 1:
        parser.error("--requests y --repetitions deben ser mayores que cero")

    warmup_url = args.warmup_url
    if warmup_url is None:
        base = args.url.split("/trips", 1)[0]
        warmup_url = f"{base}/health"

    environment = _environment_snapshot()
    environment["cpu_count"] = os.cpu_count()

    rounds: list[dict[str, object]] = []
    started_at = datetime.now(timezone.utc)

    with httpx.Client(timeout=args.timeout) as client:
        warmup_response = client.get(warmup_url)
        if warmup_response.status_code != 200:
            raise RuntimeError(
                f"El calentamiento {warmup_url} respondió "
                f"{warmup_response.status_code}; se esperaba 200"
            )
        time.sleep(args.warmup_seconds)

        for number in range(1, args.repetitions + 1):
            stats, status_codes, payload_items = _measure_round(
                client, args.url, args.requests
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
        "url": args.url,
        "warmup_url": warmup_url,
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

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
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
    print(f"Resultados crudos: {output_path}")

    return 0 if conclusion == "CUMPLE" else 1


if __name__ == "__main__":
    sys.exit(main())
