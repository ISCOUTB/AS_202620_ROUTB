"""indices espaciales GiST para matching

La busqueda de sugerencias filtra por
``ST_DWithin(t.route_geom::geography, punto::geography, radio_m)`` en
``matching/application/suggest_trips.py``. El indice debe cubrir esa
expresion exacta: un GiST sobre ``route_geom`` (geometry) no lo usa el
planificador porque la consulta castea a ``geography``.

La migracion 006 ya creo ``idx_trips_route_geog`` con la expresion
correcta. Esta migracion la renombra a ``idx_trips_route_geom_gist`` para
que el nombre coincida con el declarado en el modelo, y la recrea si
alguien la elimino. No se crean indices sobre ``origin_geom``,
``dest_geom`` ni ``stop_geom``: ninguna consulta actual los usa en un
predicado espacial (solo se leen con ``ST_X``/``ST_Y`` y
``ST_LineLocatePoint``), de modo que un GiST alli solo agregaria costo de
escritura. Ver ``docs/evidencia/indices-gist-postgis.md``.

Revision ID: 012_add_spatial_gist_indexes
Revises: 011_unique_users_phone
"""

from alembic import op


revision = "012_add_spatial_gist_indexes"
down_revision = "011_unique_users_phone"
branch_labels = None
depends_on = None


def _renombrar_si_procede(origen: str, destino: str) -> None:
    """Renombra el indice solo si el origen existe y el destino no."""
    op.execute(
        f"""
        DO $$
        BEGIN
            IF to_regclass('public.{origen}') IS NOT NULL
               AND to_regclass('public.{destino}') IS NULL THEN
                ALTER INDEX public.{origen} RENAME TO {destino};
            END IF;
        END
        $$;
        """
    )


def upgrade() -> None:
    # PostGIS puede vivir en `extensions` (Supabase); el cast a geography
    # necesita resolver el tipo aunque el indice se cree en `public`.
    op.execute("SET LOCAL search_path TO public, extensions;")

    # 006 creo el indice con la expresion correcta pero con otro nombre.
    # Se renombra para no dejar dos GiST equivalentes sobre la misma
    # expresion (el duplicado solo agregaria costo de escritura).
    _renombrar_si_procede("idx_trips_route_geog", "idx_trips_route_geom_gist")

    op.execute(
        "CREATE INDEX IF NOT EXISTS idx_trips_route_geom_gist "
        "ON trips USING GIST ((route_geom::geography));"
    )


def downgrade() -> None:
    op.execute("SET LOCAL search_path TO public, extensions;")

    # Restaura el nombre que dejo la migracion 006. Si 012 fue quien creo
    # el indice, el renombrado deja el esquema como estaba despues de 006.
    _renombrar_si_procede("idx_trips_route_geom_gist", "idx_trips_route_geog")

    op.execute(
        "CREATE INDEX IF NOT EXISTS idx_trips_route_geog "
        "ON trips USING GIST ((route_geom::geography));"
    )
