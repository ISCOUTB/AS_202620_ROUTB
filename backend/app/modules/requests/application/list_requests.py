from sqlalchemy.orm import Session, joinedload

from app.modules.requests.infrastructure.models import TripRequest


def get_trip_requests(db: Session, trip_id: int) -> list[TripRequest]:
    return (
        db.query(TripRequest)
        .options(joinedload(TripRequest.passenger))
        .filter(TripRequest.trip_id == trip_id)
        .order_by(TripRequest.created_at.desc())
        .all()
    )
