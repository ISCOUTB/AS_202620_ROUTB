from datetime import datetime
from uuid import uuid4

from app.core.database import SessionLocal
from app.core.timezone import colombia_now
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
