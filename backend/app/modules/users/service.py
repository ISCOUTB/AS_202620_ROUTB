from sqlalchemy.orm import Session
from app.modules.users import models, schemas
from app.modules.auth.service import hash_password

def create_user(db: Session, user_data: schemas.UserCreate):
    db_user = models.User(
        name=user_data.name,
        last_name=user_data.last_name,
        phone=user_data.phone,
        hashed_password=hash_password(user_data.password),
        role=user_data.role,
    )
    
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user