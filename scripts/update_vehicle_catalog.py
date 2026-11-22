"""Actualiza el catálogo local de marca y línea con las opciones públicas de SIBGA."""

import argparse
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
from threading import Lock
import time
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

BASE = "https://web.mintransporte.gov.co/Sibga/Home/"
TYPES = (1, 2, 4, 5, 12)
POPULAR_BRANDS = {
    "BMW", "BYD", "CHEVROLET", "FORD", "HONDA", "HYUNDAI", "KIA", "MAZDA",
    "MERCEDES BENZ", "NISSAN", "RENAULT", "SUZUKI", "TOYOTA", "VOLKSWAGEN",
}
CLASSES = {
    "AUTOMOVIL", "CAMIONETAS Y CAMPEROS", "CAMIONETAS DOBLECABINA",
    "CAMIONETAS DOBLE CABINA", "DOBLECABINA",
}
OUTPUT = Path(__file__).resolve().parents[1] / "frontend/assets/data/vehicle_models.json"
RATE_LOCK = Lock()
NEXT_CALL = 0.0


def fetch(operation, **params):
    global NEXT_CALL
    body = urlencode(params).encode()
    for attempt in range(3):
        with RATE_LOCK:
            time.sleep(max(0, NEXT_CALL - time.monotonic()))
            NEXT_CALL = time.monotonic() + 0.25
        try:
            with urlopen(Request(BASE + operation, data=body), timeout=15) as response:
                result = json.load(response)
            if isinstance(result, list):
                return result
            if result == "0" or result == 0:
                return []
            raise ValueError(f"Respuesta inesperada en {operation}")
        except (HTTPError, URLError, TimeoutError) as error:
            if attempt == 2 or isinstance(error, HTTPError) and error.code not in (429, 500, 502, 503, 504):
                raise
            time.sleep(2 ** (attempt + 1))


def get_models(job):
    filters, brand = job
    for row in fetch("ObtenerLineasMarca", **filters, marca=brand["id"]):
        line = " ".join(row["nombre"].split()).upper()
        model = f'{brand["nombre"].strip().upper()} {line}'
        if line and not line.startswith(("SIN LINEA", "SIN LÍNEA", "LINEAS Y CILINDRAJES", "LÍNEAS Y CILINDRAJES")):
            if len(model) <= 50 and "\ufffd" not in model:
                yield model


def collect_models(job):
    try:
        return list(get_models(job)), 0
    except (HTTPError, URLError, TimeoutError) as error:
        print(f'{job[1]["nombre"]}: {error}', flush=True)
        return [], 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--periodo", required=True, type=int)
    period = parser.parse_args().periodo
    jobs = []
    for vehicle_type in TYPES:
        filters = {"tive": vehicle_type, "periodo": period}
        classes = fetch("ObtenerClasesTipoVehiculo", **filters)
        for vehicle_class in classes:
            if vehicle_class["Nombre"].upper() not in CLASSES:
                continue
            group = {**filters, "clase": vehicle_class["Id"]}
            jobs.extend((group, brand) for brand in fetch("ObtenerMarcasTipoVehiculo", **group))
    print(f"Consultando {len(jobs)} combinaciones de marca y clase.", flush=True)
    jobs.sort(key=lambda job: job[1]["nombre"].upper() not in POPULAR_BRANDS)
    models = set()
    failures = 0
    with ThreadPoolExecutor(max_workers=3) as pool:
        for group, failed in pool.map(collect_models, jobs):
            models.update(group)
            failures += failed
    if len(models) < 100:
        raise ValueError("Catálogo incompleto")
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    if failures and OUTPUT.exists():
        # Una interrupción de la fuente no reduce un catálogo anterior.
        models.update(json.loads(OUTPUT.read_text(encoding="utf-8")))
    OUTPUT.write_text(json.dumps(sorted(models), ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{len(models)} combinaciones de marca y línea en {OUTPUT.name}.")
    print(f"Consultas sin respuesta: {failures}.")


if __name__ == "__main__":
    main()
