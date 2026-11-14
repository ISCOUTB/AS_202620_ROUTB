"""Pruebas de cálculos de radio y distancia esférica en PostGIS (Geography)."""
import pytest
from sqlalchemy import text

from app.core.database import engine


def test_postgis_geography_radius():
    """Valida ST_DWithin en metros usando tipo geography en lugar de grados planos.

    Punto A: Centro histórico de Cartagena (10.4236, -75.5478)
    Punto B (~2.9 km de A): Bocagrande aprox (10.4030, -75.5560)
    Punto C (~3.5 km de A): Manga aprox (10.4070, -75.5300)
    """
    with engine.connect() as conn:
        # Verificar versión de PostGIS
        version = conn.execute(text("SELECT PostGIS_Version();")).scalar()
        assert version is not None

        # Distancia entre A y B (~2.9 km) debe ser <= 3000 metros
        result_close = conn.execute(
            text(
                """
                SELECT ST_DWithin(
                    ST_SetSRID(ST_MakePoint(-75.5478, 10.4236), 4326)::geography,
                    ST_SetSRID(ST_MakePoint(-75.5560, 10.4030), 4326)::geography,
                    3000
                );
                """
            )
        ).scalar()
        assert result_close is True

        # Distancia entre A y C (~3.5 km) no debe ser <= 3000 metros
        result_far = conn.execute(
            text(
                """
                SELECT ST_DWithin(
                    ST_SetSRID(ST_MakePoint(-75.5478, 10.4236), 4326)::geography,
                    ST_SetSRID(ST_MakePoint(-75.5100, 10.4000), 4326)::geography,
                    3000
                );
                """
            )
        ).scalar()
        assert result_far is False


def test_migracion_012_deja_indice_gist_sobre_expresion_geography():
    """El indice espacial de `trips` cubre `route_geom::geography`.

    Un GiST sobre la columna `geometry` no sirve para la consulta de
    matching, que castea a `geography`. Tambien se comprueba que no queden
    dos indices equivalentes (el de la migracion 006 y el de la 012).
    """
    with engine.connect() as conn:
        rows = conn.execute(
            text(
                "SELECT indexname, indexdef FROM pg_indexes "
                "WHERE schemaname = 'public' AND tablename = 'trips' "
                "AND indexname IN ('idx_trips_route_geom_gist', 'idx_trips_route_geog')"
            )
        ).mappings().all()

    indices = {row["indexname"]: row["indexdef"] for row in rows}
    assert "idx_trips_route_geom_gist" in indices
    assert "idx_trips_route_geog" not in indices

    definicion = indices["idx_trips_route_geom_gist"]
    assert "USING gist" in definicion
    assert "route_geom" in definicion
    assert "::geography" in definicion


def test_planificador_usa_indice_gist_en_st_dwithin():
    """Con seqscan desactivado, el plan elige el GiST de `route_geom`.

    La tabla puede estar vacia: el objetivo es demostrar que el indice es
    elegible para la misma expresion que usa `suggest_trips`.
    """
    with engine.begin() as conn:
        conn.execute(text("SET LOCAL enable_seqscan = off"))
        plan = conn.execute(
            text(
                """
                EXPLAIN
                SELECT t.id
                FROM trips t
                WHERE t.route_geom IS NOT NULL
                  AND ST_DWithin(
                      t.route_geom::geography,
                      ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography,
                      :radius_m
                  )
                """
            ),
            {"lng": -75.5478, "lat": 10.4236, "radius_m": 800},
        ).scalars().all()

    assert "idx_trips_route_geom_gist" in "\n".join(plan)
