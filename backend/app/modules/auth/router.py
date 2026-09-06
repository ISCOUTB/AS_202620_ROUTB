from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.modules.auth import schemas, service
from app.modules.users.models import User

router = APIRouter()


@router.post("/login", response_model=schemas.TokenResponse)
def login(credentials: schemas.LoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.phone == credentials.phone).first()
    if user is None or not service.verify_password(credentials.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Teléfono o contraseña incorrectos",
        )

    return {
        "access_token": service.create_access_token(user),
        "token_type": "bearer",
        "user": {
            "id": user.id,
            "name": user.name,
            "last_name": user.last_name,
            "phone": user.phone,
            "role": user.role,
        },
    }


@router.get("/me")
def current_user(user: User = Depends(service.get_current_user)):
    return {
        "id": user.id,
        "name": user.name,
        "last_name": user.last_name,
        "phone": user.phone,
        "role": user.role,
    }