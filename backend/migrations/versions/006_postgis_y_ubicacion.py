"""Fundación espacial PostGIS y esquema de ubicación.

Revision ID: 006_postgis_y_ubicacion
Revises: 005_drop_fare_per_seat
Create Date: 2026-10-08
"""
from collections.abc import Sequence
from datetime import datetime
import re
from zoneinfo import ZoneInfo

from alembic import op
import sqlalchemy as sa
from sqlalchemy.sql import text


revision: str = "006_postgis_y_ubicacion"
down_revision: str | Sequence[str] | None = "005_drop_fare_per_seat"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def _parse_departure_to_timestamptz(date_val, time_str: str | None) -> datetime | None:
    if not date_val or not time_str:
        return None
    time_str = time_str.strip()
    match = re.match(r"^(\d{1,2}):(\d{2})\s*(AM|PM)?$", time_str, re.IGNORECASE)
    if not match:
        return None
    hour = int(match.group(1))
    minute = int(match.group(2))
    period = match.group(3)
    if period:
        period = period.upper()
        if period == "PM" and hour < 12:
            hour += 12
        elif period == "AM" and hour == 12:
            hour = 0
    if not (0 <= hour <= 23 and 0 <= minute <= 59):
        return None
    try:
        dt = datetime(date_val.year, date_val.month, date_val.day, hour, minute)
        return dt.replace(tzinfo=ZoneInfo("America/Bogota"))
    except Exception:
        return None


def upgrade() -> None:
    conn = op.get_bind()
    conn.execute(text("CREATE EXTENSION IF NOT EXISTS postgis;"))

    # 1. users: location_consent_at
    op.add_column("users", sa.Column("location_consent_at", sa.DateTime(timezone=True), nullable=True))

    # 2. trips: spatial and route columns
    op.add_column("trips", sa.Column("direction", sa.String(length=12), nullable=True))
    op.add_column("trips", sa.Column("departure_at", sa.DateTime(timezone=True), nullable=True))
    conn.execute(text("ALTER TABLE trips ADD COLUMN origin_geom GEOMETRY(Point, 4326);"))
    conn.execute(text("ALTER TABLE trips ADD COLUMN dest_geom GEOMETRY(Point, 4326);"))
    conn.execute(text("ALTER TABLE trips ADD COLUMN route_geom GEOMETRY(LineString, 4326);"))
    op.add_column("trips", sa.Column("route_distance_m", sa.Integer(), nullable=True))
    op.add_column("trips", sa.Column("route_duration_s", sa.Integer(), nullable=True))
    op.add_column("trips", sa.Column("route_source", sa.String(length=10), nullable=True))
    op.create_check_constraint(
        "trips_direction_valid",
        "trips",
        "direction IS NULL OR direction IN ('to_campus', 'from_campus')",
    )

    # 3. trip_requests: requested_at
    op.add_column("trip_requests", sa.Column("requested_at", sa.DateTime(timezone=True), nullable=True))

    # 4. request_stops table
    op.create_table(
        "request_stops",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column(
            "request_id",
            sa.Integer(),
            sa.ForeignKey("trip_requests.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("seats", sa.SmallInteger(), nullable=False),
        sa.Column("place_type", sa.String(length=14), nullable=False),
        sa.Column("address_text", sa.Text(), nullable=False),
        sa.Column("stop_seq", sa.SmallInteger(), nullable=True),
        sa.Column("eta_estimated", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint("seats BETWEEN 1 AND 4", name="check_request_stops_seats"),
        sa.CheckConstraint("place_type IN ('door', 'meeting_point')", name="request_stop_place_valid"),
    )
    conn.execute(text("ALTER TABLE request_stops ADD COLUMN stop_geom GEOMETRY(Point, 4326) NOT NULL;"))
    op.create_index("idx_request_stops_request", "request_stops", ["request_id"])

    # 5. Geocode & Route cache tables
    op.create_table(
        "geocode_cache",
        sa.Column("query", sa.Text(), primary_key=True),
        sa.Column("response", sa.dialects.postgresql.JSONB(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("NOW()"), nullable=False),
    )
    op.create_index("idx_geocode_cache_created", "geocode_cache", ["created_at"])

    op.create_table(
        "route_cache",
        sa.Column("cache_key", sa.Text(), primary_key=True),
        sa.Column("response", sa.dialects.postgresql.JSONB(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("NOW()"), nullable=False),
    )
    op.create_index("idx_route_cache_created", "route_cache", ["created_at"])

    # 6. Índices espaciales y de consulta
    conn.execute(text("CREATE INDEX idx_trips_route_geog ON trips USING GIST ((route_geom::geography));"))
    op.create_index("idx_trips_departure", "trips", ["departure_date", "status", "direction"])
    op.create_index("idx_requests_passenger_status", "trip_requests", ["passenger_id", "status"])

    # 7. Relleno tolerante de departure_at para registros existentes
    existing_trips = conn.execute(text("SELECT id, departure_date, departure_time FROM trips")).fetchall()
    for row in existing_trips:
        parsed_dt = _parse_departure_to_timestamptz(row[1], row[2])
        if parsed_dt:
            conn.execute(
                text("UPDATE trips SET departure_at = :dep WHERE id = :tid"),
                {"dep": parsed_dt, "tid": row[0]},
            )

    # 8. Función de purga de privacidad idempotente
    conn.execute(
        text(
            """
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

                -- 3. Borrar cachés vencidas
                DELETE FROM geocode_cache
                WHERE created_at < NOW() - (retention_cache_days || ' days')::INTERVAL;

                DELETE FROM route_cache
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
        )
    )


def downgrade() -> None:
    conn = op.get_bind()

    # Eliminar función purge_location_data
    conn.execute(text("DROP FUNCTION IF EXISTS purge_location_data(INTEGER, INTEGER);"))

    # Eliminar índices
    conn.execute(text("DROP INDEX IF EXISTS idx_trips_route_geog;"))
    op.drop_index("idx_trips_departure", table_name="trips")
    op.drop_index("idx_requests_passenger_status", table_name="trip_requests")
    op.drop_index("idx_route_cache_created", table_name="route_cache")
    op.drop_index("idx_geocode_cache_created", table_name="geocode_cache")
    op.drop_index("idx_request_stops_request", table_name="request_stops")

    # Eliminar tablas creadas
    op.drop_table("route_cache")
    op.drop_table("geocode_cache")
    op.drop_table("request_stops")

    # Eliminar columnas agregadas
    op.drop_column("trip_requests", "requested_at")

    op.drop_constraint("trips_direction_valid", "trips", type_="check")
    op.drop_column("trips", "route_source")
    op.drop_column("trips", "route_duration_s")
    op.drop_column("trips", "route_distance_m")
    conn.execute(text("ALTER TABLE trips DROP COLUMN IF EXISTS route_geom;"))
    conn.execute(text("ALTER TABLE trips DROP COLUMN IF EXISTS dest_geom;"))
    conn.execute(text("ALTER TABLE trips DROP COLUMN IF EXISTS origin_geom;"))
    op.drop_column("trips", "departure_at")
    op.drop_column("trips", "direction")

    op.drop_column("users", "location_consent_at")
