"""campos opcionales de vehiculo del conductor en users

Agrega columnas opcionales ``vehicle_model``, ``vehicle_plate`` y
``vehicle_color`` a la tabla ``users`` para identificar el vehiculo del
conductor ante pasajeros con solicitud confirmada.

Revision ID: 013_driver_vehicle_info
Revises: 012_add_spatial_gist_indexes
"""

from alembic import op
import sqlalchemy as sa


revision = "013_driver_vehicle_info"
down_revision = "012_add_spatial_gist_indexes"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("vehicle_model", sa.String(length=50), nullable=True),
    )
    op.add_column(
        "users",
        sa.Column("vehicle_plate", sa.String(length=10), nullable=True),
    )
    op.add_column(
        "users",
        sa.Column("vehicle_color", sa.String(length=30), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("users", "vehicle_color")
    op.drop_column("users", "vehicle_plate")
    op.drop_column("users", "vehicle_model")
