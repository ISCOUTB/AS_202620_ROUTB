from pydantic import BaseModel, Field

from app.shared.phone import PhoneNumber


class LoginRequest(BaseModel):
    phone: PhoneNumber
    password: str = Field(..., min_length=1)


class TokenResponse(BaseModel):
    access_token: str
    token_type: str
    user: dict
