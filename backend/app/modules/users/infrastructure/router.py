from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.modules.users.application.create_user import create_user
from app.modules.users.application.get_users import get_users
from app.modules.users.domain.exceptions import UserAlreadyExistsError
from app.modules.users.infrastructure import schemas

router = APIRouter()


@router.post("/", response_model=schemas.UserResponse)
def register_basic_user(
    user: schemas.UserCreate,
    db: Annotated[Session, Depends(get_db)],
):
    try:
        return create_user(db=db, user_data=user)
    except UserAlreadyExistsError as e:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=e.message,
        )


@router.get("/")
def list_users(db: Annotated[Session, Depends(get_db)]):
    return get_users(db=db)
