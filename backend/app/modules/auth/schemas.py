from typing import Literal

from pydantic import BaseModel, Field


class LoginRequest(BaseModel):
    phone: str = Field(..., min_length=1)
    password: str = Field(..., min_length=1)


class TokenResponse(BaseModel):
    access_token: str
    token_type: str
    user: dict