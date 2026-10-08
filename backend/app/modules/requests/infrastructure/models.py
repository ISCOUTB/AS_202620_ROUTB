from geoalchemy2 import Geometry
from sqlalchemy import CheckConstraint, Column, DateTime, ForeignKey, Integer, SmallInteger, String, Text, func
from sqlalchemy.orm import relationship

from app.core.database import Base


class TripRequest(Base):
    __tablename__ = "trip_requests"

    id = Column(Integer, primary_key=True, index=True)
    trip_id = Column(Integer, ForeignKey("trips.id", ondelete="CASCADE"), nullable=False, index=True)
    passenger_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    seat_count = Column(Integer, nullable=False, default=1, server_default="1")
    status = Column(String, nullable=False, default="pending", server_default="pending")
    requested_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime, server_default=func.now(), nullable=False)

    trip = relationship("Trip", back_populates="requests")
    passenger = relationship("User")
    stops = relationship("RequestStop", back_populates="request", cascade="all, delete-orphan")


class RequestStop(Base):
    __tablename__ = "request_stops"

    id = Column(Integer, primary_key=True, index=True)
    request_id = Column(Integer, ForeignKey("trip_requests.id", ondelete="CASCADE"), nullable=False, index=True)
    seats = Column(SmallInteger, nullable=False)
    place_type = Column(String(14), nullable=False)
    stop_geom = Column(Geometry(geometry_type="POINT", srid=4326, spatial_index=False), nullable=False)
    address_text = Column(Text, nullable=False)
    stop_seq = Column(SmallInteger, nullable=True)
    eta_estimated = Column(DateTime(timezone=True), nullable=True)

    __table_args__ = (
        CheckConstraint("seats BETWEEN 1 AND 4", name="check_request_stops_seats"),
        CheckConstraint("place_type IN ('door', 'meeting_point')", name="request_stop_place_valid"),
    )

    request = relationship("TripRequest", back_populates="stops")
