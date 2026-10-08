"""Pruebas de la función de purga y retención de datos de privacidad."""
from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo
import pytest
from sqlalchemy import text

from app.core.database import SessionLocal, engine
from app.modules.trips.infrastructure.models import Trip
from app.modules.requests.infrastructure.models import TripRequest, RequestStop
from app.modules.users.infrastructure.models import User


def test_purge_location_data_idempotent():
    """Valida que purge_location_data():
    1. Limpie paradas de viajes viejos (> 30 días).
    2. Anule geometrías de viajes viejos.
    3. Limpie cachés antiguas (> 7 días).
    4. Sea completamente idempotente.
    """
    db = SessionLocal()
    try:
        # 1. Crear usuario de prueba
        user = User(
            name="Privacy",
            last_name="Tester",
            phone="3009998877",
            hashed_password="fake",
            role="passenger",
        )
        db.add(user)
        db.commit()
        db.refresh(user)

        bogota_tz = ZoneInfo("America/Bogota")
        now_col = datetime.now(bogota_tz)
        old_date = (now_col - timedelta(days=40)).date()
        old_dt = now_col - timedelta(days=40)

        # 2. Crear viaje antiguo con geometrías
        old_trip = Trip(
            origin="Centro",
            destination="Campus",
            total_seats=4,
            available_seats=4,
            departure_time="7:00 AM",
            departure_date=old_date,
            departure_at=old_dt,
            driver_id=user.id,
            origin_geom="SRID=4326;POINT(-75.5478 10.4236)",
            dest_geom="SRID=4326;POINT(-75.5510 10.4238)",
            route_geom="SRID=4326;LINESTRING(-75.5478 10.4236, -75.5510 10.4238)",
            status="completed",
        )
        db.add(old_trip)
        db.commit()
        db.refresh(old_trip)

        # 3. Crear solicitud y parada asociada al viaje antiguo
        req = TripRequest(
            trip_id=old_trip.id,
            passenger_id=user.id,
            seat_count=1,
            status="accepted",
        )
        db.add(req)
        db.commit()
        db.refresh(req)

        stop = RequestStop(
            request_id=req.id,
            seats=1,
            place_type="door",
            stop_geom="SRID=4326;POINT(-75.5480 10.4237)",
            address_text="Calle 30 #10-20",
        )
        db.add(stop)
        db.commit()

        # 4. Insertar registros en cache antiguos
        db.execute(
            text(
                "INSERT INTO geocode_cache (query, response, created_at) "
                "VALUES ('test old query', '{\"res\": 1}'::jsonb, NOW() - INTERVAL '10 days')"
            )
        )
        db.execute(
            text(
                "INSERT INTO route_cache (cache_key, response, created_at) "
                "VALUES ('test_key', '{\"res\": 1}'::jsonb, NOW() - INTERVAL '10 days')"
            )
        )
        db.commit()

        # 5. Ejecutar purge_location_data()
        db.execute(text("SELECT purge_location_data(30, 7);"))
        db.commit()

        # 6. Verificaciones
        # a) Parada borrada
        remaining_stops = db.query(RequestStop).filter(RequestStop.request_id == req.id).count()
        assert remaining_stops == 0

        # b) Geometrías del viaje anuladas
        refreshed_trip = db.query(Trip).filter(Trip.id == old_trip.id).first()
        assert refreshed_trip.origin_geom is None
        assert refreshed_trip.dest_geom is None
        assert refreshed_trip.route_geom is None

        # c) Cachés viejas eliminadas
        old_geo = db.execute(text("SELECT COUNT(*) FROM geocode_cache WHERE query = 'test old query'")).scalar()
        assert old_geo == 0
        old_route = db.execute(text("SELECT COUNT(*) FROM route_cache WHERE cache_key = 'test_key'")).scalar()
        assert old_route == 0

        # 7. Idempotencia: ejecutarla de nuevo no debe lanzar error
        db.execute(text("SELECT purge_location_data(30, 7);"))
        db.commit()

    finally:
        db.close()
