import importlib.util
import os
from concurrent.futures import ThreadPoolExecutor

import pytest
from alembic import command
from alembic.config import Config
from fastapi.testclient import TestClient
from sqlalchemy import text

from app.core.database import DATABASE_URL, SessionLocal, engine
from app.main import app
from app.modules.users.application.create_user import create_user
from app.modules.users.domain.exceptions import UserAlreadyExistsError
from app.modules.users.infrastructure.models import User
from app.modules.users.infrastructure.schemas import UserCreate

# Inicializamos el cliente para simular peticiones web
client = TestClient(app)

def test_registro_usuario_exitoso():
    # PARTE 1: Preparación del payload según Swagger
    payload = {
        "name": "Juan",
        "last_name": "Pérez",
        "phone": "3001234567",
        "password": "PasswordSegura123!",
        "role": "driver",
    }

    # PARTE 2: Ejecución de la petición a la ruta exacta
    response = client.post("/users/", json=payload)

    # PARTE 3: Validación de la respuesta (código 200 y validación de datos)
    assert response.status_code == 200
    
    # Validamos que la base de datos devuelva la confirmación estructurada
    data = response.json()
    assert data["name"] == "Juan"
    assert data["last_name"] == "Pérez"
    assert data["phone"] == "3001234567"
    assert data["role"] == "driver"
    assert "id" in data # Confirma que se le asignó un ID en la base de datos


def test_login_devuelve_jwt():
    response = client.post(
        "/auth/login",
        json={"phone": "3001234567", "password": "PasswordSegura123!"},
    )

    assert response.status_code == 200
    data = response.json()
    assert data["token_type"] == "bearer"
    assert data["access_token"]
    assert data["user"]["role"] == "driver"


def test_auth_me_devuelve_perfil_completo():
    """El perfil de solo lectura incluye nombre, apellido y rol."""
    token = client.post(
        "/auth/login",
        json={"phone": "3001234567", "password": "PasswordSegura123!"},
    ).json()["access_token"]

    response = client.get(
        "/auth/me", headers={"Authorization": f"Bearer {token}"}
    )

    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "Juan"
    assert data["last_name"] == "Pérez"
    assert data["phone"] == "3001234567"
    assert data["role"] == "driver"
    assert "location_consent_at" not in data


def _payload(phone: str, name: str = "Ana") -> dict:
    return {
        "name": name,
        "last_name": "Ruiz",
        "phone": phone,
        "password": "PasswordSegura123!",
        "role": "passenger",
    }


def _borrar_por_telefono(*phones: str) -> None:
    with SessionLocal() as db:
        db.query(User).filter(User.phone.in_(phones)).delete(synchronize_session=False)
        db.commit()


def test_registro_duplicado_devuelve_409():
    """Un segundo registro con el mismo telefono responde 409, no 500."""
    phone = "3007771001"
    _borrar_por_telefono(phone)
    try:
        first = client.post("/users/", json=_payload(phone))
        assert first.status_code == 200, first.text

        second = client.post("/users/", json=_payload(phone, name="Otro"))
        assert second.status_code == 409
        assert second.json()["detail"] == "El teléfono ya está registrado"

        with SessionLocal() as db:
            assert db.query(User).filter(User.phone == phone).count() == 1
    finally:
        _borrar_por_telefono(phone)


def test_registro_concurrente_mismo_telefono_deja_un_usuario():
    """Dos o mas altas simultaneas dejan un solo usuario y el resto en 409."""
    phone = "3007771002"
    intentos = 8
    _borrar_por_telefono(phone)

    def registrar(_index: int):
        return client.post("/users/", json=_payload(phone))

    try:
        with ThreadPoolExecutor(max_workers=intentos) as executor:
            responses = list(executor.map(registrar, range(intentos)))

        codes = [response.status_code for response in responses]
        assert codes.count(200) == 1, codes
        assert codes.count(409) == intentos - 1, codes
        assert all(
            response.status_code != 409
            or response.json()["detail"] == "El teléfono ya está registrado"
            for response in responses
        )

        with SessionLocal() as db:
            assert db.query(User).filter(User.phone == phone).count() == 1
    finally:
        _borrar_por_telefono(phone)


def test_create_user_traduce_violacion_del_indice_unico():
    """Si la lectura previa no ve el duplicado, el indice igual responde 409."""
    phone = "3007771003"
    payload = UserCreate(**_payload(phone))
    _borrar_por_telefono(phone)

    with SessionLocal() as db:
        create_user(db, payload)

    try:
        with SessionLocal() as db:
            def query_sin_duplicado(*_entities, **_kwargs):
                class _Vacio:
                    def filter(self, *_args, **_kw):
                        return self

                    def first(self):
                        return None

                return _Vacio()

            db.query = query_sin_duplicado
            with pytest.raises(UserAlreadyExistsError, match="ya está registrado"):
                create_user(db, payload)

        with SessionLocal() as db:
            assert db.query(User).filter(User.phone == phone).count() == 1
    finally:
        _borrar_por_telefono(phone)


def _migracion():
    path = os.path.join(
        os.path.dirname(__file__),
        "..",
        "migrations",
        "versions",
        "011_unique_users_phone.py",
    )
    spec = importlib.util.spec_from_file_location("migracion_011", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_canonical_phone_acepta_solo_los_tres_formatos():
    migracion = _migracion()
    assert migracion.canonical_phone("3007771004") == "3007771004"
    assert migracion.canonical_phone("+57 300-777-1004") == "3007771004"
    assert migracion.canonical_phone("57 300 777 1004") == "3007771004"
    assert migracion.canonical_phone("+573007771004") == "3007771004"
    assert migracion.canonical_phone("12345") is None
    assert migracion.canonical_phone("+57 300") is None
    assert migracion.canonical_phone("(300) 777-1004") is None


def _alembic_config() -> Config:
    cfg = Config(os.path.join(os.path.dirname(__file__), "..", "alembic.ini"))
    cfg.set_main_option("sqlalchemy.url", DATABASE_URL.replace("%", "%%"))
    return cfg


def _insertar_telefono(phone: str) -> int:
    with engine.begin() as conn:
        return conn.execute(
            text(
                "INSERT INTO users (name, last_name, phone, hashed_password, role) "
                "VALUES ('Norma', 'Test', :phone, 'hash', 'passenger') "
                "RETURNING id"
            ),
            {"phone": phone},
        ).scalar_one()


def _telefono(user_id: int) -> str:
    with engine.connect() as conn:
        return conn.execute(
            text("SELECT phone FROM users WHERE id = :id"),
            {"id": user_id},
        ).scalar_one()


def _borrar_ids(*user_ids: int) -> None:
    if not user_ids:
        return
    with engine.begin() as conn:
        for user_id in user_ids:
            conn.execute(
                text("DELETE FROM users WHERE id = :id"),
                {"id": user_id},
            )


def _indice_telefono() -> bool:
    with engine.connect() as conn:
        found = conn.execute(
            text(
                "SELECT 1 FROM pg_indexes "
                "WHERE schemaname = 'public' AND indexname = 'uq_users_phone'"
            )
        ).scalar()
    return found is not None


def test_migracion_011_normaliza_aborta_duplicados_y_es_reversible():
    """Saneamiento sin perdida de datos, aborta si hay duplicados y vuelve atras."""
    cfg = _alembic_config()
    ids: list[int] = []
    command.downgrade(cfg, "010_solicitud_activa_unica")
    try:
        assert _indice_telefono() is False

        ya_canonico = _insertar_telefono("3007772001")
        con_prefijo = _insertar_telefono("+57 300-777-2002")
        con_pais = _insertar_telefono("57 300 777 2003")
        ids.extend([ya_canonico, con_prefijo, con_pais])

        command.upgrade(cfg, "011_unique_users_phone")
        assert _telefono(ya_canonico) == "3007772001"
        assert _telefono(con_prefijo) == "3007772002"
        assert _telefono(con_pais) == "3007772003"
        assert _indice_telefono() is True

        command.downgrade(cfg, "010_solicitud_activa_unica")
        assert _indice_telefono() is False
        # El downgrade no deshace la normalizacion: restaurar prefijos
        # reabriria colisiones. Los valores canonicos se conservan.
        assert _telefono(con_prefijo) == "3007772002"
        command.upgrade(cfg, "head")
        assert _indice_telefono() is True

        command.downgrade(cfg, "010_solicitud_activa_unica")
        duplicado_a = _insertar_telefono("3007772004")
        duplicado_b = _insertar_telefono("+57 300-777-2004")
        invalido = _insertar_telefono("12345")
        ids.extend([duplicado_a, duplicado_b, invalido])

        with pytest.raises(Exception, match="no se pueden normalizar"):
            command.upgrade(cfg, "011_unique_users_phone")
        assert _telefono(invalido) == "12345"
        assert _telefono(duplicado_b) == "+57 300-777-2004"
        assert _indice_telefono() is False

        _borrar_ids(invalido)
        ids.remove(invalido)

        with pytest.raises(Exception, match="teléfonos duplicados"):
            command.upgrade(cfg, "011_unique_users_phone")
        assert _telefono(duplicado_a) == "3007772004"
        assert _telefono(duplicado_b) == "+57 300-777-2004"
        assert _indice_telefono() is False
    finally:
        _borrar_ids(*ids)
        command.upgrade(cfg, "head")
        assert _indice_telefono() is True