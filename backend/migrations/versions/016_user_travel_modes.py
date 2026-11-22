"""Preferencia de modalidad para cuentas de transporte compartido."""

from alembic import op
import sqlalchemy as sa

revision = "016_user_travel_modes"
down_revision = "015_support_reports"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("users", sa.Column("driver_activated_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("users", sa.Column("preferred_mode", sa.String(), nullable=True))
    # NULL conserva el modo histórico hasta que la persona elija otro.
    op.create_check_constraint(
        "ck_users_travel_mode", "users",
        "preferred_mode = 'passenger' OR (preferred_mode = 'driver' AND (role = 'driver' OR driver_activated_at IS NOT NULL))",
    )


def downgrade():
    op.drop_constraint("ck_users_travel_mode", "users", type_="check")
    op.drop_column("users", "preferred_mode")
    op.drop_column("users", "driver_activated_at")
