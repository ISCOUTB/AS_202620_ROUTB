from sqlalchemy import Column, Index, Integer, String
from app.core.database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    last_name = Column(String, nullable=False)
    # Un solo indice unico. No usar unique=True e index=True a la vez:
    # crearian nombres distintos ademas de uq_users_phone (migracion 011).
    phone = Column(String, nullable=False)
    hashed_password = Column(String, nullable=False)
    role = Column(String, nullable=False, default="passenger", server_default="passenger")
    vehicle_model = Column(String(50), nullable=True)
    vehicle_plate = Column(String(10), nullable=True)
    vehicle_color = Column(String(30), nullable=True)

    __table_args__ = (
        Index("uq_users_phone", "phone", unique=True),
    )
