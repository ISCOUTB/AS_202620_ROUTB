from pydantic import BaseModel, field_validator
from typing import Literal


class DeviceTokenUpsert(BaseModel):
    device_token: str
    platform: Literal["android", "ios"]

    @field_validator("device_token")
    @classmethod
    def token_not_empty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("device_token no puede estar vacío")
        return v.strip()


class DeviceTokenResponse(BaseModel):
    id: int
    user_id: int
    device_token: str
    platform: str

    model_config = {"from_attributes": True}
