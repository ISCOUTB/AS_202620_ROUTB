"""quitar la columna de consentimiento propio de ubicacion

El consentimiento de ubicacion pasa a depender del permiso del sistema
operativo. Se retira ``location_consent_at`` de ``users`` junto con los
endpoints que lo gestionaban.

Revision ID: 014_remove_location_consent
Revises: 013_driver_vehicle_info
"""

from alembic import op
import sqlalchemy as sa


revision = "014_remove_location_consent"
down_revision = "013_driver_vehicle_info"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.drop_column("users", "location_consent_at")


def downgrade() -> None:
    op.add_column(
        "users",
        sa.Column("location_consent_at", sa.DateTime(timezone=True), nullable=True),
    )
