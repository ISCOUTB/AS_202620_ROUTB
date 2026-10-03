"""Add date, meetup point, and per-seat contribution to trips.

Revision ID: 004_trip_schedule_details
Revises: 003_group_trip_request_seats
Create Date: 2026-10-02
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "004_trip_schedule_details"
down_revision: Union[str, Sequence[str], None] = "003_group_trip_request_seats"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "trips",
        sa.Column(
            "departure_date",
            sa.Date(),
            server_default=sa.text("CURRENT_DATE"),
            nullable=False,
        ),
    )
    op.add_column(
        "trips",
        sa.Column(
            "meeting_point",
            sa.String(),
            server_default="Por coordinar",
            nullable=False,
        ),
    )
    op.add_column(
        "trips",
        sa.Column("fare_per_seat", sa.Integer(), server_default="0", nullable=False),
    )


def downgrade() -> None:
    op.drop_column("trips", "fare_per_seat")
    op.drop_column("trips", "meeting_point")
    op.drop_column("trips", "departure_date")
