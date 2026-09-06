import os

os.environ["TESTING"] = "1"

import pytest

from app.core.database import Base, DATABASE_URL, engine
from app.modules.trips.models import Trip


if DATABASE_URL == os.getenv("DATABASE_URL"):
    raise RuntimeError(
        "Pruebas bloqueadas: DATABASE_URL_TEST coincide con DATABASE_URL. "
        "Usa una base de datos de tests separada."
    )


@pytest.fixture(scope="session", autouse=True)
def crear_tablas():
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)
