from datetime import datetime
from uuid import uuid4

from fastapi.testclient import TestClient

from app.core.database import SessionLocal
from app.core.timezone import colombia_now
from app.main import app
from app.modules.auth.application.tokens import create_access_token
from app.modules.requests.infrastructure.models import RequestStop, TripRequest
from app.modules.trips.infrastructure.models import Trip
from app.modules.users.application.location_consent import revoke_location_consent
from app.modules.users.infrastructure.models import User


def test_revoke_consent_cancels_pending_and_deletes_saved_stops():
    with SessionLocal() as db:
        user = User(
            name="Privacy",
            last_name="Tester",
            phone=f"300{uuid4().int % 10_000_000:07d}",
            hashed_password="fake",
            role="passenger",
            location_consent_at=colombia_now(),
        )
        db.add(user)
        db.flush()
        trip = Trip(
            origin="Centro",
            destination="Campus",
            total_seats=2,
            available_seats=2,
            departure_time="7:00 AM",
            departure_date=datetime.now().date(),
            status="active",
        )
        db.add(trip)
        db.flush()
        request = TripRequest(
            trip_id=trip.id, passenger_id=user.id, seat_count=1, status="pending"
        )
        db.add(request)
        db.flush()
        stop = RequestStop(
            request_id=request.id,
            seats=1,
            place_type="door",
            stop_geom="SRID=4326;POINT(-75.5 10.4)",
            address_text="Centro",
        )
        db.add(stop)
        db.commit()

        revoke_location_consent(db, user.id)

        db.refresh(user)
        db.refresh(request)
        assert user.location_consent_at is None
        assert request.status == "cancelled"
        assert db.query(RequestStop).filter_by(request_id=request.id).count() == 0
        db.delete(trip)
        db.delete(user)
        db.commit()


def test_auth_me_refleja_el_consentimiento_otorgado():
    """El perfil (`GET /auth/me`) muestra la autorización en cuanto se otorga."""
    client = TestClient(app)
    with SessionLocal() as db:
        user = User(
            name="Perfil",
            last_name="Consentimiento",
            phone=f"300{uuid4().int % 10_000_000:07d}",
            hashed_password="fake",
            role="passenger",
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        user_id = user.id
        token = create_access_token(user.id, user.role)

    headers = {"Authorization": f"Bearer {token}"}
    try:
        before = client.get("/auth/me", headers=headers)
        assert before.status_code == 200
        assert before.json()["location_consent_at"] is None

        granted = client.post("/users/me/location-consent", headers=headers)
        assert granted.status_code == 204

        after = client.get("/auth/me", headers=headers)
        assert after.status_code == 200
        assert after.json()["location_consent_at"] is not None
    finally:
        with SessionLocal() as db:
            user = db.get(User, user_id)
            if user:
                db.delete(user)
                db.commit()
