from sqlalchemy import Column, Integer, String
from sqlalchemy import Column, ForeignKey, Integer, String
from sqlalchemy.orm import relationship

from app.core.database import Base


class Trip(Base):
    __tablename__ = "trips"

    id = Column(Integer, primary_key=True, index=True)
    origin = Column(String, nullable=False)
    destination = Column(String, nullable=False)
    total_seats = Column(Integer, nullable=False)
    available_seats = Column(Integer, nullable=False)
    driver_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    departure_time = Column(String, nullable=True, default="7:00 AM")
    status = Column(String, nullable=False, default="active", server_default="active")

    driver = relationship("User")
    requests = relationship("TripRequest", back_populates="trip", cascade="all, delete-orphan")