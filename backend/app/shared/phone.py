"""Normalización compartida de teléfonos celulares colombianos.

Registro y login aceptan los mismos formatos y entregan siempre el número
canónico de 10 dígitos que se guarda en la base de datos.
"""

import re
from typing import Annotated

from pydantic import BeforeValidator, Field

PHONE_PATTERN = r"^(?:\+?57)?3\d{9}$"
PHONE_DESCRIPTION = (
    "Celular colombiano de 10 dígitos. Acepta los formatos 3XXXXXXXXX, "
    "573XXXXXXXXX y +573XXXXXXXXX después de retirar espacios y guiones."
)

_SEPARATORS = re.compile(r"[\s-]")
_CANONICAL_PHONE = re.compile(r"^3\d{9}$")


def normalize_phone(value: str) -> str:
    """Devuelve el celular en 10 dígitos o lanza ``ValueError`` si no es válido."""
    digits = _SEPARATORS.sub("", value)
    if digits.startswith("+"):
        digits = digits[1:]
    if digits.startswith("57") and len(digits) == 12:
        digits = digits[2:]

    if not _CANONICAL_PHONE.fullmatch(digits):
        raise ValueError(
            "El teléfono debe ser un celular colombiano de 10 dígitos"
        )
    return digits


def _normalize_input(value: object) -> object:
    if not isinstance(value, str):
        return value
    return normalize_phone(value)


PhoneNumber = Annotated[
    str,
    Field(
        pattern=PHONE_PATTERN,
        description=PHONE_DESCRIPTION,
    ),
    BeforeValidator(_normalize_input),
]
