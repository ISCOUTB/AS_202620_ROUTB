"""Esquemas compartidos entre módulos."""

from pydantic import BaseModel, Field


class RoutePoint(BaseModel):
    """Punto de una geometría de ruta, en orden latitud/longitud."""

    lat: float = Field(..., ge=-90, le=90)
    lng: float = Field(..., ge=-180, le=180)
