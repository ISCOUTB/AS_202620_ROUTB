import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
from sqlalchemy.pool import NullPool
from dotenv import load_dotenv

load_dotenv()

if os.getenv("TESTING") == "1":
    DATABASE_URL = os.getenv("DATABASE_URL_TEST")
    if not DATABASE_URL:
        raise RuntimeError(
            "TESTING=1 requiere definir DATABASE_URL_TEST en backend/.env"
        )
else:
    DATABASE_URL = os.getenv("DATABASE_URL")
    if not DATABASE_URL:
        raise RuntimeError("DATABASE_URL no está configurada")

engine = create_engine(DATABASE_URL, poolclass=NullPool)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()