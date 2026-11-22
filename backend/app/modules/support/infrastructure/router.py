from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.modules.auth.infrastructure.security import get_current_user
from app.modules.support.application.create_report import SubmissionConflict, create_report
from app.modules.support.infrastructure.schemas import SupportReportCreate, SupportReportReceipt
from app.modules.users.application import UserIdentity

router = APIRouter()


@router.post(
    "/reports",
    response_model=SupportReportReceipt,
    status_code=status.HTTP_201_CREATED,
    responses={
        401: {"description": "Sesión requerida"},
        409: {"description": "Identificador de envío usado con otro contenido"},
    },
)
def submit_report(
    payload: SupportReportCreate,
    db: Annotated[Session, Depends(get_db)],
    current_user: Annotated[UserIdentity, Depends(get_current_user)],
) -> SupportReportReceipt:
    """Guarda un reporte de soporte y devuelve su folio."""
    try:
        report_id = create_report(db, user_id=current_user.id, **payload.model_dump())
    except SubmissionConflict as error:
        raise HTTPException(status_code=409, detail="submission_conflict") from error
    return SupportReportReceipt(id=report_id)
