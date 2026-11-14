from datetime import datetime
from typing import Literal
from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.shared.phone import PhoneNumber
from app.shared.vehicle import normalize_vehicle_plate


class UserCreate(BaseModel):
    name: str = Field(..., min_length=2, max_length=50)
    last_name: str = Field(..., min_length=2, max_length=50)
    phone: PhoneNumber
    password: str = Field(
        ...,
        min_length=8,
        max_length=128,
        description="Contraseña de al menos 8 caracteres",
    )
    role: Literal["passenger", "driver"] = "passenger"


class VehicleUpdate(BaseModel):
    vehicle_model: str | None = Field(
        default=None,
        max_length=50,
        description="Marca y línea del vehículo (ej. Chevrolet Spark)",
    )
    vehicle_plate: str | None = Field(
        default=None,
        max_length=10,
        description="Placa colombiana de automóvil (ej. XYZ-123)",
    )
    vehicle_color: str | None = Field(
        default=None,
        max_length=30,
        description="Color del vehículo (ej. Gris)",
    )

    @model_validator(mode="after")
    def validate_and_normalize_vehicle(self):
        model = (self.vehicle_model or "").strip() or None
        plate = (self.vehicle_plate or "").strip() or None
        color = (self.vehicle_color or "").strip() or None

        if model is None and plate is None and color is None:
            self.vehicle_model = None
            self.vehicle_plate = None
            self.vehicle_color = None
            return self

        if model is None or plate is None:
            raise ValueError(
                "Debes indicar tanto el modelo como la placa del vehículo"
            )
        if len(model) < 2:
            raise ValueError(
                "El modelo del vehículo debe tener al menos 2 caracteres"
            )
        if color is not None and len(color) < 2:
            raise ValueError(
                "El color del vehículo debe tener al menos 2 caracteres"
            )

        self.vehicle_model = model
        self.vehicle_plate = normalize_vehicle_plate(plate)
        self.vehicle_color = color
        return self


class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    last_name: str
    phone: str
    role: Literal["passenger", "driver"]
    location_consent_at: datetime | None = None
    vehicle_model: str | None = None
    vehicle_plate: str | None = None
    vehicle_color: str | None = None
