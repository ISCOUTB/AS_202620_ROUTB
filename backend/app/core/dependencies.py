from typing import Annotated
from fastapi import Depends
from sqlalchemy.orm import Session

from app.core.database import get_db

# Dependencia compartida de base de datos para inyección en routers
DbSession = Annotated[Session, Depends(get_db)]
