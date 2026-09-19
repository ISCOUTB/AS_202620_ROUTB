from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.modules.auth.application.login import login as login_use_case
from app.modules.auth.domain.exceptions import InvalidCredentialsError
from app.modules.auth.infrastructure import schemas
from app.modules.auth.infrastructure.security import get_current_user
from app.modules.users.infrastructure.models import User

router = APIRouter()


@router.post("/login", response_model=schemas.TokenResponse)
def login(
    credentials: schemas.LoginRequest,
    db: Annotated[Session, Depends(get_db)],
):
    try:
        return login_use_case(db=db, credentials=credentials)
    except InvalidCredentialsError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=e.message,
        )


@router.get("/me")
def current_user(
    user: Annotated[User, Depends(get_current_user)],
):
    return {
        "id": user.id,
        "name": user.name,
        "last_name": user.last_name,
        "phone": user.phone,
        "role": user.role,
    }
