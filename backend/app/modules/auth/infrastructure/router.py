from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.modules.auth.application.login import login as login_use_case
from app.modules.auth.domain.exceptions import InvalidCredentialsError
from app.modules.auth.infrastructure import schemas
from app.modules.auth.infrastructure.security import get_current_user
from app.modules.users.application import UserIdentity
from app.modules.users.infrastructure.schemas import UserResponse

router = APIRouter()


@router.post("/login", response_model=schemas.TokenResponse)
def login(
    credentials: schemas.LoginRequest,
    db: Annotated[Session, Depends(get_db)],
):
    try:
        return login_use_case(
            db=db,
            phone=credentials.phone,
            password=credentials.password,
        )
    except InvalidCredentialsError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=e.message,
        )


@router.get("/me", response_model=UserResponse)
def current_user(
    user: Annotated[UserIdentity, Depends(get_current_user)],
):
    return user
