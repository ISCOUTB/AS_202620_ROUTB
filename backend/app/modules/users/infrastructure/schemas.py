from typing import Literal
from pydantic import BaseModel, ConfigDict, Field


class UserCreate(BaseModel):
    name: str = Field(..., min_length=1)
    last_name: str = Field(..., min_length=1)
    phone: str = Field(..., min_length=1)
    password: str = Field(..., min_length=1)
    role: Literal["passenger", "driver"] = "passenger"


class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    last_name: str
    phone: str
    role: Literal["passenger", "driver"]
