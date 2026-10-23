"""retirar geocode_cache

La geocodificación pasa a resolverse en el cliente Flutter con Google Maps
Platform. El backend ya no usa ``geocode_cache`` ni el endpoint
``GET /geocode/search``, así que esta migración retira la tabla y actualiza
``purge_location_data()`` para que no intente borrar de una tabla inexistente.

Revision ID: 009_retirar_geocode_cache
Revises: 008_device_tokens_identity
"""

from alembic import op

# revision identifiers, used by Alembic.
revision = "009_retirar_geocode_cache"
down_revision = "008_device_tokens_identity"
branch_labels = None
depends_on = None


def _purge_sql(include_geocode: bool) -> str:
    geocode_delete = (
        "\n                DELETE FROM geocode_cache"
        "\n                WHERE created_at < NOW() - (retention_cache_days || ' days')::INTERVAL;"
        if include_geocode
        else ""
    )
    geocode_comment = "" if include_geocode else " (solo route_cache)"
    return f"""
        CREATE OR REPLACE FUNCTION purge_location_data(
            retention_trip_days INTEGER DEFAULT 30,
            retention_cache_days INTEGER DEFAULT 7
        )
        RETURNS void AS $$
        BEGIN
            -- 1. Borrar paradas de solicitudes cuyos viajes salieron hace más de retention_trip_days
            DELETE FROM request_stops
            WHERE request_id IN (
                SELECT r.id FROM trip_requests r
                JOIN trips t ON r.trip_id = t.id
                WHERE t.departure_at < NOW() - (retention_trip_days || ' days')::INTERVAL
                   OR (t.departure_at IS NULL AND t.departure_date < (CURRENT_DATE - retention_trip_days))
            );

            -- 2. Anular coordenadas de viajes antiguos (incluso sin conductor)
            UPDATE trips
            SET origin_geom = NULL,
                dest_geom = NULL,
                route_geom = NULL
            WHERE departure_at < NOW() - (retention_trip_days || ' days')::INTERVAL
               OR (departure_at IS NULL AND departure_date < (CURRENT_DATE - retention_trip_days));

            -- 3. Borrar cachés vencidas{geocode_comment}
{geocode_delete}            DELETE FROM route_cache
            WHERE created_at < NOW() - (retention_cache_days || ' days')::INTERVAL;

            -- 4. Borrar tokens de dispositivos inactivos si la tabla existe
            IF EXISTS (
                SELECT FROM information_schema.tables
                WHERE table_schema = 'public' AND table_name = 'device_tokens'
            ) THEN
                DELETE FROM device_tokens WHERE last_seen_at < NOW() - INTERVAL '60 days';
            END IF;
        END;
        $$ LANGUAGE plpgsql;
    """


def upgrade() -> None:
    op.execute(_purge_sql(include_geocode=False))
    op.execute("DROP INDEX IF EXISTS idx_geocode_cache_created")
    op.execute("DROP TABLE IF EXISTS geocode_cache")


def downgrade() -> None:
    op.execute(
        """
        CREATE TABLE IF NOT EXISTS geocode_cache (
            query TEXT PRIMARY KEY,
            response JSONB NOT NULL,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
        """
    )
    op.execute(
        "CREATE INDEX IF NOT EXISTS idx_geocode_cache_created "
        "ON geocode_cache (created_at)"
    )
    op.execute(_purge_sql(include_geocode=True))
