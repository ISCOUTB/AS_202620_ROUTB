from uuid import UUID

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from app.modules.support.infrastructure.models import SupportReport


class SubmissionConflict(Exception):
    """El mismo identificador ya se usó para otro contenido."""


def create_report(
    db: Session, *, user_id: int, submission_id: UUID, category: str, description: str
) -> int:
    statement = (
        insert(SupportReport)
        .values(
            user_id=user_id,
            submission_id=submission_id,
            category=category,
            description=description,
        )
        .on_conflict_do_nothing(constraint="uq_support_report_submission")
        .returning(SupportReport.id)
    )
    report_id = db.scalar(statement)
    if report_id is None:
        existing = db.scalars(
            select(SupportReport).filter_by(user_id=user_id, submission_id=submission_id)
        ).one()
        if (existing.category, existing.description) != (category, description):
            raise SubmissionConflict
        report_id = existing.id
    db.commit()
    return report_id
