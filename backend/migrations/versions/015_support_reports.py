"""agregar reportes de soporte

Revision ID: 015_support_reports
Revises: 014_remove_location_consent
"""

import sqlalchemy as sa
from alembic import op

revision = "015_support_reports"
down_revision = "014_remove_location_consent"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "support_reports",
        sa.Column("id", sa.Integer(), sa.Identity(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("submission_id", sa.Uuid(), nullable=False),
        sa.Column("category", sa.String(20), nullable=False),
        sa.Column("description", sa.String(2000), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("user_id", "submission_id", name="uq_support_report_submission"),
    )


def downgrade() -> None:
    op.drop_table("support_reports")
