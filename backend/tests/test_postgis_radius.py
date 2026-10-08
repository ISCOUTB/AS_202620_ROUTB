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
