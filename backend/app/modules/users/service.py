from sqlalchemy.orm import Session
from app.modules.users import models, schemas

def create_user(db: Session, user_data: schemas.UserCreate):
    fake_hashed_password = user_data.password + "notreallyhashed"
    
    db_user = models.User(
        name=user_data.name,
        last_name=user_data.last_name,
        phone=user_data.phone,
        hashed_password=fake_hashed_password
    )
    
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user