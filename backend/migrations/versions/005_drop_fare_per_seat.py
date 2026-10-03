"""Remove the unsupported per-seat contribution from trips.

Revision ID: 005_drop_fare_per_seat
Revises: 004_trip_schedule_details
Create Date: 2026-10-03
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "005_drop_fare_per_seat"
down_revision: Union[str, Sequence[str], None] = "004_trip_schedule_details"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.drop_column("trips", "fare_per_seat")


def downgrade() -> None:
    op.add_column(
        "trips",
        sa.Column("fare_per_seat", sa.Integer(), server_default="0", nullable=False),
    )
