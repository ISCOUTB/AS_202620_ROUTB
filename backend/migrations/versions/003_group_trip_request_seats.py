"""Add a passenger count to each trip request.

Revision ID: 003_group_trip_request_seats
Revises: 002_update_trips_requests
Create Date: 2026-10-02
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "003_group_trip_request_seats"
down_revision: Union[str, Sequence[str], None] = "002_update_trips_requests"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "trip_requests",
        sa.Column("seat_count", sa.Integer(), server_default="1", nullable=False),
    )


def downgrade() -> None:
    op.drop_column("trip_requests", "seat_count")
