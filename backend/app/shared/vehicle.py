"""Validación y formateo compartido de datos de vehículo del conductor.

Valida placas colombianas de automóvil (``ABC-123``) y construye el resumen
``vehicle_info`` que solo se expone al pasajero con solicitud aceptada. ROUTB
transporta estudiantes en automóviles: no se aceptan placas de motocicleta.
"""

import re

_PLATE_SEPARATORS = re.compile(r"[\s\-]+")
_COLOMBIAN_PLATE = re.compile(r"^([A-Z]{3})(\d{3})$")


def normalize_vehicle_plate(value: str) -> str:
    """Normaliza una placa colombiana de automóvil a ``ABC-123`` o lanza ``ValueError``."""
    compact = _PLATE_SEPARATORS.sub("", value.strip().upper())
    match = _COLOMBIAN_PLATE.fullmatch(compact)
    if match is None:
        raise ValueError(
            "La placa debe tener formato colombiano de automóvil (ej. ABC-123)"
        )
    return f"{match.group(1)}-{match.group(2)}"


def format_vehicle_info(driver: object | None) -> str | None:
    """Construye la ficha legible del vehículo si el conductor la registró."""
    if driver is None:
        return None
    model = (getattr(driver, "vehicle_model", None) or "").strip()
    color = (getattr(driver, "vehicle_color", None) or "").strip()
    plate = (getattr(driver, "vehicle_plate", None) or "").strip()
    if not model and not plate and not color:
        return None
    head = " · ".join(part for part in (model, color) if part)
    if head and plate:
        return f"{head} ({plate})"
    if head:
        return head
    return plate
