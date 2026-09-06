from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.modules.users import schemas, service
from app.modules.users.models import User

router = APIRouter()

@router.post("/", response_model=schemas.UserResponse)
def register_basic_user(user: schemas.UserCreate, db: Session = Depends(get_db)):
    if db.query(User).filter(User.phone == user.phone).first() is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="El teléfono ya está registrado",
        )
    return service.create_user(db=db, user_data=user)

@router.get("/")
def get_users(db: Session = Depends(get_db)):
    return db.query(User).all()