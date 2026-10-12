"""Ayudas compartidas para las pruebas de solicitudes con paradas.

Reúne la preparación idéntica que antes vivía duplicada en
`test_request_stops.py` y `test_requests_assignment.py`: limpieza de
usuarios, creación de viajes con dirección y paradas de prueba dentro del
BBOX de Cartagena. Cada prueba conserva sus propios datos y condiciones;
aquí solo vive lo mecánico.
"""

from fastapi.testclient import TestClient

from app.core.database import SessionLocal
from app.core.timezone import colombia_now, colombia_today
from app.main import app
from app.modules.auth.application.tokens import create_access_token
from app.modules.requests.infrastructure.models import TripRequest
from app.modules.trips.infrastructure.models import Trip
from app.modules.users.infrastructure.models import User

client = TestClient(app)

# Hora futura para que los viajes de prueba no se venzan durante la suite.
FUTURE_TIME = "11:59 PM"

# Coordenadas dentro del BBOX de Cartagena.
STOP_LAT = 10.42
STOP_LNG = -75.54


def crear_usuario(
    telefono: str,
    role: str = "passenger",
    nombre: str = "Test",
    apellido: str = "Usuario",
    consentimiento: str | None = "auto",
) -> tuple[int, str]:
    """Crea un usuario y devuelve `(id, token)`.

    Con `consentimiento="auto"` (valor por defecto) los pasajeros nacen con
    consentimiento de ubicación y los conductores sin él; con
    `consentimiento=None` nadie lo tiene. Así se conservan los dos
    comportamientos que las pruebas ya usaban.
    """
    consent_at = None
    if consentimiento == "auto" and role != "driver":
        consent_at = colombia_now()
    with SessionLocal() as db:
        user = User(
            name=nombre,
            last_name=apellido,
            phone=telefono,
            hashed_password="hash",
            role=role,
            location_consent_at=consent_at,
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        return user.id, create_access_token(user.id, user.role)


def limpiar(*user_ids: int) -> None:
    """Borra usuarios con sus viajes y solicitudes, sin dejar huérfanas."""
    with SessionLocal() as db:
        for uid in user_ids:
            db.query(TripRequest).filter(
                TripRequest.passenger_id == uid
            ).delete(synchronize_session=False)
            for trip in db.query(Trip).filter(Trip.driver_id == uid).all():
                db.query(TripRequest).filter(
                    TripRequest.trip_id == trip.id
                ).delete(synchronize_session=False)
                db.delete(trip)
            user = db.get(User, uid)
            if user:
                db.delete(user)
        db.commit()


def crear_viaje(
    driver_token: str, total_seats: int = 4, direction: str = "to_campus"
) -> int:
    """Publica un viaje con dirección y devuelve su id."""
    resp = client.post(
        "/trips/",
        headers={"Authorization": f"Bearer {driver_token}"},
        json={
            "origin": "Centro",
            "destination": "UTB",
            "total_seats": total_seats,
            "departure_time": FUTURE_TIME,
            "departure_date": str(colombia_today()),
            "direction": direction,
        },
    )
    assert resp.status_code == 201, resp.text
    return resp.json()["id"]


def parada(
    seats: int = 1, lat: float = STOP_LAT, lng: float = STOP_LNG
) -> dict:
    """Una parada válida dentro del área de operación."""
    return {
        "seats": seats,
        "place_type": "door",
        "lat": lat,
        "lng": lng,
        "address_text": "Calle de prueba 123",
    }
