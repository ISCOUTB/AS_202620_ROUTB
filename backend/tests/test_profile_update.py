"""G15: edición de datos personales y cambio de contraseña.

Cubre la autorización por token, la unicidad del teléfono y la verificación
con la contraseña actual. El endpoint de perfil no recibe un identificador:
siempre opera sobre el usuario del token.
"""

from fastapi.testclient import TestClient

from app.main import app
from tests.helpers import limpiar

client = TestClient(app)

PASSWORD = "PasswordSegura123!"
NEW_PASSWORD = "NuevaPassword456!"


def _auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def _register(
    phone: str,
    *,
    name: str = "Ana",
    last_name: str = "Ruiz",
    role: str = "passenger",
) -> tuple[int, str]:
    response = client.post(
        "/users/",
        json={
            "name": name,
            "last_name": last_name,
            "phone": phone,
            "password": PASSWORD,
            "role": role,
        },
    )
    assert response.status_code == 200, response.text
    user_id = response.json()["id"]

    login = client.post(
        "/auth/login",
        json={"phone": phone, "password": PASSWORD},
    )
    assert login.status_code == 200, login.text
    return user_id, login.json()["access_token"]


def _profile(token: str) -> dict:
    response = client.get("/auth/me", headers=_auth(token))
    assert response.status_code == 200, response.text
    return response.json()


def test_actualiza_nombre_apellido_y_telefono():
    user_id, token = _register("3520000001")
    try:
        updated = client.patch(
            "/users/me",
            headers=_auth(token),
            json={
                "name": "  Carolina  ",
                "last_name": "  Méndez ",
                "phone": " 300 555 0101 ",
            },
        )

        assert updated.status_code == 200, updated.text
        data = updated.json()
        assert data["name"] == "Carolina"
        assert data["last_name"] == "Méndez"
        assert data["phone"] == "3005550101"

        assert _profile(token)["phone"] == "3005550101"

        # El teléfono es el usuario de ingreso: el nuevo funciona y el viejo no.
        new_login = client.post(
            "/auth/login",
            json={"phone": "3005550101", "password": PASSWORD},
        )
        assert new_login.status_code == 200, new_login.text

        old_login = client.post(
            "/auth/login",
            json={"phone": "3520000001", "password": PASSWORD},
        )
        assert old_login.status_code == 401
    finally:
        limpiar(user_id)


def test_telefono_duplicado_devuelve_409_y_no_cambia_nada():
    first_id, first_token = _register("3520000002", name="Primera")
    second_id, _ = _register("3520000003", name="Segunda")
    try:
        duplicate = client.patch(
            "/users/me",
            headers=_auth(first_token),
            json={
                "name": "Primera",
                "last_name": "Ruiz",
                "phone": "3520000003",
            },
        )

        assert duplicate.status_code == 409
        assert duplicate.json()["detail"] == "El teléfono ya está registrado"
        assert _profile(first_token)["phone"] == "3520000002"
    finally:
        limpiar(first_id, second_id)


def test_mismo_telefono_del_usuario_es_valido():
    user_id, token = _register("3520000004")
    try:
        updated = client.patch(
            "/users/me",
            headers=_auth(token),
            json={
                "name": "Ana María",
                "last_name": "Ruiz",
                "phone": "3520000004",
            },
        )

        assert updated.status_code == 200, updated.text
        assert updated.json()["name"] == "Ana María"
    finally:
        limpiar(user_id)


def test_perfil_invalido_da_422():
    user_id, token = _register("3520000005")
    try:
        blank_name = client.patch(
            "/users/me",
            headers=_auth(token),
            json={"name": "   ", "last_name": "Ruiz", "phone": "3005550102"},
        )
        assert blank_name.status_code == 422

        invalid_phone = client.patch(
            "/users/me",
            headers=_auth(token),
            json={"name": "Ana", "last_name": "Ruiz", "phone": "123"},
        )
        assert invalid_phone.status_code == 422
    finally:
        limpiar(user_id)


def test_no_puede_editar_los_datos_de_otra_persona():
    first_id, first_token = _register("3520000006", name="Primera")
    second_id, second_token = _register("3520000007", name="Segunda")
    try:
        updated = client.patch(
            "/users/me",
            headers=_auth(first_token),
            json={
                "name": "Primera Editada",
                "last_name": "Ruiz",
                "phone": "3520000006",
            },
        )
        assert updated.status_code == 200, updated.text

        assert _profile(second_token)["name"] == "Segunda"
    finally:
        limpiar(first_id, second_id)


def test_endpoints_exigen_autenticacion():
    assert (
        client.patch(
            "/users/me",
            json={"name": "Ana", "last_name": "Ruiz", "phone": "3005550103"},
        ).status_code
        == 401
    )
    assert (
        client.patch(
            "/users/me/password",
            json={
                "current_password": PASSWORD,
                "new_password": NEW_PASSWORD,
            },
        ).status_code
        == 401
    )


def test_cambia_contrasena_con_verificacion():
    user_id, token = _register("3520000008")
    try:
        wrong = client.patch(
            "/users/me/password",
            headers=_auth(token),
            json={
                "current_password": "NoEsLaCorrecta1!",
                "new_password": NEW_PASSWORD,
            },
        )
        assert wrong.status_code == 400
        assert wrong.json()["detail"] == "La contraseña actual no es correcta"

        # Un intento fallido no cambia la contraseña.
        still_old = client.post(
            "/auth/login",
            json={"phone": "3520000008", "password": PASSWORD},
        )
        assert still_old.status_code == 200

        changed = client.patch(
            "/users/me/password",
            headers=_auth(token),
            json={
                "current_password": PASSWORD,
                "new_password": NEW_PASSWORD,
            },
        )
        assert changed.status_code == 204, changed.text

        old_login = client.post(
            "/auth/login",
            json={"phone": "3520000008", "password": PASSWORD},
        )
        assert old_login.status_code == 401

        new_login = client.post(
            "/auth/login",
            json={"phone": "3520000008", "password": NEW_PASSWORD},
        )
        assert new_login.status_code == 200, new_login.text
    finally:
        limpiar(user_id)


def test_nueva_contrasena_corta_da_422():
    user_id, token = _register("3520000009")
    try:
        response = client.patch(
            "/users/me/password",
            headers=_auth(token),
            json={"current_password": PASSWORD, "new_password": "corta"},
        )
        assert response.status_code == 422

        login = client.post(
            "/auth/login",
            json={"phone": "3520000009", "password": PASSWORD},
        )
        assert login.status_code == 200
    finally:
        limpiar(user_id)
