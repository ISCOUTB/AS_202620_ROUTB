from sqlalchemy import Column, DateTime, ForeignKey, Identity, Integer, String, UniqueConstraint, Uuid, func

from app.core.database import Base


class SupportReport(Base):
    __tablename__ = "support_reports"
    __table_args__ = (
        UniqueConstraint("user_id", "submission_id", name="uq_support_report_submission"),
    )

    id = Column(Integer, Identity(), primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    submission_id = Column(Uuid, nullable=False)
    category = Column(String(20), nullable=False)
    description = Column(String(2000), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
