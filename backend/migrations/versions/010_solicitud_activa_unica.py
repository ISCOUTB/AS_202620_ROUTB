"""solicitud activa unica por pasajero y viaje

Garantiza en la base de datos que un pasajero no tenga dos solicitudes
activas (``pending`` o ``accepted``) para el mismo viaje. La comprobación
previa de ``create_request`` se conserva como respuesta temprana, pero la
garantía queda en el índice único parcial, de modo que dos peticiones
simultáneas no puedan colarse entre la lectura y la inserción.

Antes de crear el índice se cancelan los duplicados pendientes que hayan
podido quedar por esa carrera. Si existe una solicitud aceptada para la
misma combinación, se conserva y se cancelan solo las pendientes.

Revision ID: 010_solicitud_activa_unica
Revises: 009_retirar_geocode_cache
"""

from alembic import op

# revision identifiers, used by Alembic.
revision = "010_solicitud_activa_unica"
down_revision = "009_retirar_geocode_cache"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Conciliar duplicados históricos: se conserva la solicitud aceptada si
    # existe; en su defecto, la más antigua. El resto de pendientes pasa a
    # ``cancelled`` (no retienen cupos).
    op.execute(
        """
        WITH ranked AS (
            SELECT
                id,
                status,
                row_number() OVER (
                    PARTITION BY trip_id, passenger_id
                    ORDER BY (status = 'accepted') DESC, id ASC
                ) AS position
            FROM trip_requests
            WHERE status IN ('pending', 'accepted')
        )
        UPDATE trip_requests
        SET status = 'cancelled'
        WHERE id IN (
            SELECT id FROM ranked WHERE position > 1 AND status = 'pending'
        );
        """
    )
    op.execute(
        "CREATE UNIQUE INDEX uq_trip_requests_active_passenger "
        "ON trip_requests (trip_id, passenger_id) "
        "WHERE status IN ('pending', 'accepted')"
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS uq_trip_requests_active_passenger")
