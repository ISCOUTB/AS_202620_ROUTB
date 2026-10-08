import os

os.environ["TESTING"] = "1"

import pytest

from app.core.database import Base, DATABASE_URL, engine
from app.modules.trips.infrastructure.models import Trip


if DATABASE_URL == os.getenv("DATABASE_URL"):
    raise RuntimeError(
        "Pruebas bloqueadas: DATABASE_URL_TEST coincide con DATABASE_URL. "
        "Usa una base de datos de tests separada."
    )


from alembic import command
from alembic.config import Config
from sqlalchemy import text


@pytest.fixture(scope="session", autouse=True)
def crear_tablas():
    with engine.begin() as conn:
        conn.execute(text("CREATE EXTENSION IF NOT EXISTS postgis;"))

    alembic_cfg = Config(os.path.join(os.path.dirname(__file__), "..", "alembic.ini"))
    alembic_cfg.set_main_option("sqlalchemy.url", DATABASE_URL.replace("%", "%%"))

    command.upgrade(alembic_cfg, "head")
    yield
    command.downgrade(alembic_cfg, "base")
