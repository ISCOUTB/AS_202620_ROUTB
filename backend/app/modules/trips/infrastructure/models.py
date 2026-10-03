from datetime import date, datetime
from zoneinfo import ZoneInfo

from sqlalchemy import Column, Date, ForeignKey, Integer, String, func
from sqlalchemy.orm import relationship

from app.core.database import Base


def _colombia_today() -> date:
    return datetime.now(ZoneInfo("America/Bogota")).date()


class Trip(Base):
    __tablename__ = "trips"

    id = Column(Integer, primary_key=True, index=True)
    origin = Column(String, nullable=False)
    destination = Column(String, nullable=False)
    total_seats = Column(Integer, nullable=False)
    available_seats = Column(Integer, nullable=False)
    driver_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    departure_time = Column(String, nullable=True, default="7:00 AM")
    departure_date = Column(
        Date, nullable=False, default=_colombia_today, server_default=func.current_date()
    )
    meeting_point = Column(
        String, nullable=False, default="Por coordinar", server_default="Por coordinar"
    )
    fare_per_seat = Column(Integer, nullable=False, default=0, server_default="0")
    status = Column(String, nullable=False, default="active", server_default="active")

    driver = relationship("User")
    requests = relationship("TripRequest", back_populates="trip", cascade="all, delete-orphan")
