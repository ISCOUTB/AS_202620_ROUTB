"""Siembra viajes activos en la base de datos de pruebas para la medición S14.

El script solo escribe en ``DATABASE_URL_TEST`` y se niega a ejecutarse si esa
URL coincide con ``DATABASE_URL``. Crea viajes con un origen identificable para
poder retirarlos después con ``--clean``.

Uso desde la raíz del repositorio:

    backend/.venv/Scripts/python.exe scripts/sembrar_viajes_medicion.py --count 5
    backend/.venv/Scripts/python.exe scripts/sembrar_viajes_medicion.py --clean

Antes de sembrar, aplica las migraciones sobre la base de pruebas:

    cd backend
    $env:TESTING = "1"
    .\\.venv\\Scripts\\python.exe -m alembic upgrade head
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

os.environ.setdefault("TESTING", "1")

WORKSPACE_ROOT = Path(__file__).resolve().parents[1]
BACKEND_DIR = WORKSPACE_ROOT / "backend"
sys.path.insert(0, str(BACKEND_DIR))

from app.core.config import settings  # noqa: E402
from app.core.database import SessionLocal  # noqa: E402
from app.core.timezone import colombia_today  # noqa: E402
from app.modules.requests.infrastructure import models as _requests_models  # noqa: E402,F401
from app.modules.trips.infrastructure import models as _trips_models  # noqa: E402
from app.modules.users.infrastructure import models as _users_models  # noqa: E402,F401
from app.modules.notifications.infrastructure import models as _notifications_models  # noqa: E402,F401

SEED_PREFIX = "Medición S14"


def _validate_test_database() -> None:
    if not settings.TESTING:
        raise SystemExit("TESTING debe ser 1; este script no escribe en producción")
    if not settings.DATABASE_URL_TEST:
        raise SystemExit("Falta DATABASE_URL_TEST en backend/.env")
    if settings.DATABASE_URL_TEST == settings.DATABASE_URL:
        raise SystemExit("DATABASE_URL_TEST coincide con DATABASE_URL; se aborta")


def _clean(db) -> int:
    deleted = (
        db.query(_trips_models.Trip)
        .filter(_trips_models.Trip.origin.like(f"{SEED_PREFIX}%"))
        .delete(synchronize_session=False)
    )
    db.commit()
    return deleted


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--count", type=int, default=5, help="Viajes a sembrar")
    parser.add_argument(
        "--clean", action="store_true", help="Retira los viajes sembrados y sale"
    )
    args = parser.parse_args()

    _validate_test_database()

    with SessionLocal() as db:
        if args.clean:
            deleted = _clean(db)
            print(f"Viajes retirados: {deleted}")
        else:
            if args.count < 1:
                parser.error("--count debe ser mayor que cero")

            deleted = _clean(db)
            if deleted:
                print(f"Viajes previos retirados: {deleted}")

            trips = [
                _trips_models.Trip(
                    origin=f"{SEED_PREFIX} origen {index}",
                    destination="Campus UTB",
                    total_seats=4,
                    available_seats=4,
                    departure_time="7:00 AM",
                    departure_date=colombia_today(),
                    meeting_point="Punto de medición",
                    status="active",
                    direction="to_campus",
                )
                for index in range(1, args.count + 1)
            ]
            db.add_all(trips)
            db.commit()
            ids = [trip.id for trip in trips]
            print(f"Viajes sembrados: {len(ids)} (ids: {ids})")
            print("Base de datos: DATABASE_URL_TEST (no producción)")

    return 0


if __name__ == "__main__":
    sys.exit(main())
