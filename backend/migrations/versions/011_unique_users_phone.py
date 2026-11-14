"""indice unico en users.phone

Normaliza los telefonos existentes al formato canonico de 10 digitos
(celular colombiano) y crea el indice unico ``uq_users_phone``.

Formatos aceptados, despues de quitar espacios y guiones:
``3XXXXXXXXX``, ``+573XXXXXXXXX`` y ``573XXXXXXXXX``. En base de datos
queda siempre ``3XXXXXXXXX``.

Si un telefono no se puede normalizar, o si dos filas colisionan al
normalizar, la migracion aborta con un mensaje claro. No borra ni fusiona
usuarios: no escribe nada hasta comprobar que el indice se puede crear.
El ``downgrade`` solo retira el indice; no restaura el formato anterior,
porque volver a prefijos distintos reabriria la misma colision.

Revision ID: 011_unique_users_phone
Revises: 010_solicitud_activa_unica
"""

import re

from alembic import op
import sqlalchemy as sa


revision = "011_unique_users_phone"
down_revision = "010_solicitud_activa_unica"
branch_labels = None
depends_on = None

# Misma regla que app.shared.phone.normalize_phone. Se copia aqui para que
# reejecutar esta migracion no dependa de cambios futuros del normalizador.
_SEPARATORS = re.compile(r"[\s\-]+")
_TEN_DIGITS = re.compile(r"^3\d{9}$")
_WITH_COUNTRY = re.compile(r"^(?:\+57|57)(3\d{9})$")

_MAX_DETALLE = 20


def canonical_phone(raw: str | None) -> str | None:
    """Devuelve el celular de 10 digitos, o None si el valor no es aceptable."""
    if raw is None:
        return None
    cleaned = _SEPARATORS.sub("", str(raw).strip())
    if _TEN_DIGITS.fullmatch(cleaned):
        return cleaned
    match = _WITH_COUNTRY.fullmatch(cleaned)
    if match is not None:
        return match.group(1)
    return None


def _detalle(items: list[str]) -> str:
    visible = items[:_MAX_DETALLE]
    texto = "; ".join(visible)
    ocultos = len(items) - len(visible)
    if ocultos > 0:
        texto = f"{texto}; y {ocultos} mas"
    return texto


def upgrade() -> None:
    conn = op.get_bind()
    rows = conn.execute(
        sa.text("SELECT id, phone FROM users ORDER BY id")
    ).fetchall()

    invalidos: list[str] = []
    por_canonico: dict[str, list[tuple[int, str]]] = {}
    cambios: list[tuple[int, str]] = []

    for row in rows:
        canonico = canonical_phone(row.phone)
        if canonico is None:
            invalidos.append(f"id={row.id} phone={row.phone!r}")
            continue
        por_canonico.setdefault(canonico, []).append((row.id, row.phone))
        if row.phone != canonico:
            cambios.append((row.id, canonico))

    # Abortar antes de escribir: un fallo aqui no modifica filas.
    if invalidos:
        raise RuntimeError(
            "Migración 011 abortada: hay teléfonos que no se pueden "
            "normalizar a 10 dígitos. Formatos aceptados, tras quitar "
            "espacios y guiones: 3XXXXXXXXX, +573XXXXXXXXX y 573XXXXXXXXX. "
            "No se borró ni se fusionó ningún usuario. Corrige estos "
            "registros a mano y vuelve a ejecutar la migración: "
            + _detalle(invalidos)
        )

    duplicados = [
        (
            f"{canonico} <- "
            + ", ".join(f"id={uid} phone={original!r}" for uid, original in items)
        )
        for canonico, items in por_canonico.items()
        if len(items) > 1
    ]
    if duplicados:
        raise RuntimeError(
            "Migración 011 abortada: hay teléfonos duplicados tras "
            "normalizar al formato de 10 dígitos. No se borró ni se fusionó "
            "ningún usuario. Resuelve los duplicados a mano y vuelve a "
            "ejecutar la migración: "
            + _detalle(duplicados)
        )

    for user_id, canonico in cambios:
        conn.execute(
            sa.text("UPDATE users SET phone = :phone WHERE id = :id"),
            {"phone": canonico, "id": user_id},
        )

    op.create_index("uq_users_phone", "users", ["phone"], unique=True)


def downgrade() -> None:
    op.drop_index("uq_users_phone", table_name="users")
