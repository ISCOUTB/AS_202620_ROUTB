import pytest
from app.core.database import engine, Base
from app.modules.trips.models import Trip

@pytest.fixture(scope="session", autouse=True)
def crear_tablas():
    # Crea todas las tablas definidas en los modelos antes de correr los tests
    Base.metadata.create_all(bind=engine)
    yield
    # Opcional: elimina las tablas al terminar toda la sesión de tests
    Base.metadata.drop_all(bind=engine)
