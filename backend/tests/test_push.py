"""Pruebas de notificaciones push (Fase 2 - Bloque 3.3).

Usa mocks de Firebase para que la suite funcione sin credenciales reales.
"""

from unittest.mock import MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.core.database import SessionLocal
from app.core.timezone import colombia_today
from app.main import app
from app.modules.auth.application.tokens import create_access_token
from app.modules.notifications.domain.exceptions import DeviceTokenRegistrationError
from app.modules.notifications.infrastructure.models import DeviceToken
from app.modules.requests.infrastructure.models import TripRequest
from app.modules.trips.infrastructure.models import Trip
from app.modules.users.infrastructure.models import User

client = TestClient(app)

_FUTURE_TIME = "11:59 PM"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _crear_usuario(telefono: str, role: str = "passenger") -> tuple[int, str]:
    with SessionLocal() as db:
        user = User(
            name="Push",
            last_name="Test",
            phone=telefono,
            hashed_password="hash",
            role=role,
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        return user.id, create_access_token(user.id, user.role)


def _limpiar(*user_ids: int) -> None:
    with SessionLocal() as db:
        for uid in user_ids:
            db.query(DeviceToken).filter(DeviceToken.user_id == uid).delete(synchronize_session=False)
            db.query(TripRequest).filter(TripRequest.passenger_id == uid).delete(synchronize_session=False)
            for trip in db.query(Trip).filter(Trip.driver_id == uid).all():
                db.query(TripRequest).filter(TripRequest.trip_id == trip.id).delete(synchronize_session=False)
                db.delete(trip)
            user = db.get(User, uid)
            if user:
                db.delete(user)
        db.commit()


def _registrar_token(user_token: str, fcm_token: str = "fcm_push_test") -> None:
    resp = client.put(
        "/notifications/device-token",
        headers={"Authorization": f"Bearer {user_token}"},
        json={"device_token": fcm_token, "platform": "android"},
    )
    assert resp.status_code == 200


def _crear_viaje(driver_token: str, total_seats: int = 2) -> int:
    resp = client.post(
        "/trips/",
        headers={"Authorization": f"Bearer {driver_token}"},
        json={
            "origin": "Centro",
            "destination": "UTB",
            "total_seats": total_seats,
            "departure_time": _FUTURE_TIME,
            "departure_date": str(colombia_today()),
        },
    )
    assert resp.status_code == 201
    return resp.json()["id"]


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

def test_sin_credenciales_fcm_el_backend_sigue_respondiendo():
    """Sin configurar FCM_PROJECT_ID ni FCM_SERVICE_ACCOUNT_B64, la API no falla."""
    driver_id, driver_token = _crear_usuario("3400000001", "driver")
    passenger_id, passenger_token = _crear_usuario("3400000002", "passenger")

    try:
        trip_id = _crear_viaje(driver_token)
        resp = client.post(
            f"/requests/trips/{trip_id}",
            headers={"Authorization": f"Bearer {passenger_token}"},
        )
        # Si la creación falla el viaje puede ser legado (sin direction): 201 siempre
        assert resp.status_code == 201
    finally:
        _limpiar(passenger_id, driver_id)


def test_token_invalido_se_elimina_automaticamente():
    """Un token marcado como UnregisteredError por FCM se elimina de la BD."""
    from firebase_admin.messaging import UnregisteredError

    from app.modules.notifications.application.send_notification import send_push

    driver_id, driver_token = _crear_usuario("3400000003", "driver")

    try:
        # Registrar token
        _registrar_token(driver_token, "fcm_invalid_token_xyz")

        # Verificar que existe
        with SessionLocal() as db:
            count = db.query(DeviceToken).filter(
                DeviceToken.device_token == "fcm_invalid_token_xyz"
            ).count()
        assert count == 1

        # Simular respuesta de FCM con token inválido
        mock_response = MagicMock()
        mock_response.success = False
        mock_response.exception = UnregisteredError("token unregistered")

        mock_batch = MagicMock()
        mock_batch.success_count = 0
        mock_batch.failure_count = 1
        mock_batch.responses = [mock_response]

        with SessionLocal() as db:
            with patch(
                "app.modules.notifications.application.send_notification._get_app",
                return_value=MagicMock(),
            ), patch(
                "firebase_admin.messaging.send_each",
                return_value=mock_batch,
            ):
                send_push(["fcm_invalid_token_xyz"], title="Test", body="Test", db=db)

        # El token debe haberse eliminado
        with SessionLocal() as db:
            count = db.query(DeviceToken).filter(
                DeviceToken.device_token == "fcm_invalid_token_xyz"
            ).count()
        assert count == 0
    finally:
        _limpiar(driver_id)


def test_fallo_fcm_no_revierte_la_transaccion_rest():
    """Un fallo de FCM no revierte la solicitud ni bloquea la respuesta."""
    driver_id, driver_token = _crear_usuario("3400000004", "driver")
    passenger_id, passenger_token = _crear_usuario("3400000005", "passenger")

    try:
        trip_id = _crear_viaje(driver_token)

        # Parchear send_push para que lance excepción
        with patch(
            "app.modules.requests.application.create_request.send_push",
            side_effect=Exception("FCM caído"),
        ):
            resp = client.post(
                f"/requests/trips/{trip_id}",
                headers={"Authorization": f"Bearer {passenger_token}"},
            )
        # A pesar del fallo FCM, la solicitud debe crearse
        assert resp.status_code == 201
    finally:
        _limpiar(passenger_id, driver_id)


def test_notificacion_al_pasajero_al_aceptar():
    """Al aceptar una solicitud se intenta notificar al pasajero (mocked)."""
    driver_id, driver_token = _crear_usuario("3400000006", "driver")
    passenger_id, passenger_token = _crear_usuario("3400000007", "passenger")

    try:
        _registrar_token(passenger_token, "fcm_passenger_token_accept")
        trip_id = _crear_viaje(driver_token)

        created = client.post(
            f"/requests/trips/{trip_id}",
            headers={"Authorization": f"Bearer {passenger_token}"},
        )
        assert created.status_code == 201
        req_id = created.json()["id"]

        sent_calls = []

        def _mock_send_push(tokens, title, body, data=None, db=None):
            sent_calls.append({"tokens": tokens, "title": title})
            return len(tokens)

        with patch(
            "app.modules.requests.application.manage_request.send_push",
            side_effect=_mock_send_push,
        ):
            resp = client.patch(
                f"/requests/{req_id}/accept",
                headers={"Authorization": f"Bearer {driver_token}"},
            )
        assert resp.status_code == 200
        # Debe haber intentado notificar al pasajero
        assert any("fcm_passenger_token_accept" in c["tokens"] for c in sent_calls)
    finally:
        _limpiar(passenger_id, driver_id)


def test_no_se_registran_tokens_en_logs():
    """Verificar que send_push no hace logging a nivel WARNING/ERROR con tokens en el mensaje."""
    import logging

    from app.modules.notifications.application.send_notification import send_push

    log_records: list[logging.LogRecord] = []

    class _Collector(logging.Handler):
        def emit(self, record):
            log_records.append(record)

    handler = _Collector()
    logger = logging.getLogger("routb.notifications")
    logger.addHandler(handler)

    try:
        # Sin FCM configurado, simplemente retorna 0 sin loggear tokens
        result = send_push(
            tokens=["secret_token_12345"],
            title="Test",
            body="Hello",
        )
        assert result == 0
        # Ningún registro debe contener el token en sí
        for record in log_records:
            assert "secret_token_12345" not in record.getMessage()
    finally:
        logger.removeHandler(handler)


def test_registro_de_token_genera_id_en_la_base():
    """El ``id`` de ``device_tokens`` lo genera la base, no el cliente.

    Regresión del ``NotNullViolation`` que en producción devolvía 500: el alta
    debe persistir el token y asignar un id sin recibirlo del cliente.
    """
    user_id, user_token = _crear_usuario("3400000008", "driver")

    try:
        _registrar_token(user_token, "fcm_id_gen_1")
        _registrar_token(user_token, "fcm_id_gen_2")

        with SessionLocal() as db:
            ids = [
                row.id
                for row in db.query(DeviceToken)
                .filter(DeviceToken.user_id == user_id)
                .all()
            ]

        assert len(ids) == 2
        assert all(i is not None for i in ids)
        assert len(set(ids)) == 2
    finally:
        _limpiar(user_id)


def test_modelo_device_token_id_es_entero_con_identity():
    """El modelo exige ``id`` entero generado por la base.

    Es el contrato que la migración 008 restaura en producción: si la columna
    deja de ser entera o pierde la generación, este test avisa.
    """
    from sqlalchemy import Integer

    columna = DeviceToken.__table__.c.id
    assert isinstance(columna.type, Integer)
    assert columna.identity is not None


def test_registro_token_con_fallo_de_bd_devuelve_500_claro():
    """Un fallo de persistencia del token se traduce a 500 con detalle."""
    user_id, user_token = _crear_usuario("3400000009", "driver")

    try:
        with patch(
            "app.modules.notifications.infrastructure.router.upsert_token",
            side_effect=DeviceTokenRegistrationError(),
        ):
            resp = client.put(
                "/notifications/device-token",
                headers={"Authorization": f"Bearer {user_token}"},
                json={"device_token": "fcm_error", "platform": "android"},
            )

        assert resp.status_code == 500
        assert resp.json()["detail"] == "device_token_registration_failed"
    finally:
        _limpiar(user_id)
