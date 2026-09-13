"""Actualizar tabla trips y crear tabla trip_requests.

Revision ID: 002_update_trips_requests
Revises: 001_crear_users_y_trips
Create Date: 2026-09-13
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "002_update_trips_requests"
down_revision: Union[str, Sequence[str], None] = "001_crear_users_y_trips"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Actualizar tabla trips
    op.add_column("trips", sa.Column("driver_id", sa.Integer(), nullable=True))
    op.create_foreign_key(
        "fk_trips_driver_id_users",
        "trips",
        "users",
        ["driver_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.create_index("ix_trips_driver_id", "trips", ["driver_id"], unique=False)

    op.add_column("trips", sa.Column("departure_time", sa.String(), server_default="7:00 AM", nullable=True))
    op.add_column("trips", sa.Column("status", sa.String(), server_default="active", nullable=False))

    # Crear tabla trip_requests
    op.create_table(
        "trip_requests",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("trip_id", sa.Integer(), nullable=False),
        sa.Column("passenger_id", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(), server_default="pending", nullable=False),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["trip_id"], ["trips.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["passenger_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_trip_requests_id", "trip_requests", ["id"], unique=False)
    op.create_index("ix_trip_requests_trip_id", "trip_requests", ["trip_id"], unique=False)
    op.create_index("ix_trip_requests_passenger_id", "trip_requests", ["passenger_id"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_trip_requests_passenger_id", table_name="trip_requests")
    op.drop_index("ix_trip_requests_trip_id", table_name="trip_requests")
    op.drop_index("ix_trip_requests_id", table_name="trip_requests")
    op.drop_table("trip_requests")

    op.drop_column("trips", "status")
    op.drop_column("trips", "departure_time")
    op.drop_index("ix_trips_driver_id", table_name="trips")
    op.drop_constraint("fk_trips_driver_id_users", "trips", type_="foreignkey")
    op.drop_column("trips", "driver_id")

