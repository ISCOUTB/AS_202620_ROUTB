"""Ordena las paradas y recalcula la ruta con paradas aceptadas."""

import json
from datetime import timedelta

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.shared.routing.service import calculate_route
from app.modules.trips.application.create_trip import _parse_departure_to_timestamptz


def reorder_accepted_stops(db: Session, trip_id: int) -> None:
    stop_ids = db.execute(
        text(
            """SELECT s.id FROM request_stops s
               JOIN trip_requests r ON r.id = s.request_id
               JOIN trips t ON t.id = r.trip_id
               WHERE r.trip_id = :trip_id AND r.status = 'accepted'
                 AND t.route_geom IS NOT NULL
               ORDER BY ST_LineLocatePoint(t.route_geom, s.stop_geom), s.id"""
        ).bindparams(trip_id=trip_id)
    ).scalars().all()
    for sequence, stop_id in enumerate(stop_ids, start=1):
        db.execute(
            text("UPDATE request_stops SET stop_seq = :seq WHERE id = :stop_id").bindparams(
                seq=sequence, stop_id=stop_id
            )
        )


def refresh_trip_route_and_stop_eta(db: Session, trip_id: int) -> None:
    """Recalcula la ruta y las ETA después de cerrar la aceptación."""
    trip = db.execute(
        text(
            """SELECT ST_Y(origin_geom) AS origin_lat, ST_X(origin_geom) AS origin_lng,
                      ST_Y(dest_geom) AS dest_lat, ST_X(dest_geom) AS dest_lng,
                      departure_at, departure_date, departure_time
               FROM trips WHERE id = :trip_id"""
        ).bindparams(trip_id=trip_id)
    ).mappings().one_or_none()
    if not trip or trip["origin_lat"] is None or trip["dest_lat"] is None:
        return

    stops = db.execute(
        text(
            """SELECT s.id, ST_Y(s.stop_geom) AS lat, ST_X(s.stop_geom) AS lng
               FROM request_stops s JOIN trip_requests r ON r.id = s.request_id
               WHERE r.trip_id = :trip_id AND r.status = 'accepted'
               ORDER BY s.stop_seq NULLS LAST, s.id"""
        ).bindparams(trip_id=trip_id)
    ).mappings().all()
    coords = [(trip["origin_lat"], trip["origin_lng"])]
    coords.extend((stop["lat"], stop["lng"]) for stop in stops)
    coords.append((trip["dest_lat"], trip["dest_lng"]))
    route = calculate_route(db, coords)
    geometry = json.dumps({"type": "LineString", "coordinates": route["geometry"]})
    db.execute(
        text(
            """UPDATE trips SET route_geom = ST_SetSRID(ST_GeomFromGeoJSON(:geometry), 4326),
                      route_distance_m = :distance, route_duration_s = :duration,
                      route_source = :source WHERE id = :trip_id"""
        ).bindparams(
            geometry=geometry,
            distance=route["distance_m"],
            duration=route["duration_s"],
            source=route["source"],
            trip_id=trip_id,
        )
    )
    departure = trip["departure_at"] or _parse_departure_to_timestamptz(
        trip["departure_date"], trip["departure_time"]
    )
    if departure is None:
        db.commit()
        return
    for stop in db.execute(
        text(
            """SELECT s.id,
                      ST_LineLocatePoint(
                          ST_SetSRID(ST_GeomFromGeoJSON(:geometry), 4326), s.stop_geom
                      ) AS fraction
               FROM request_stops s JOIN trip_requests r ON r.id = s.request_id
               WHERE r.trip_id = :trip_id AND r.status = 'accepted'
               ORDER BY s.stop_seq NULLS LAST, s.id"""
        ).bindparams(geometry=geometry, trip_id=trip_id)
    ).mappings().all():
        eta = departure + timedelta(seconds=route["duration_s"] * float(stop["fraction"]))
        db.execute(
            text("UPDATE request_stops SET eta_estimated = :eta WHERE id = :stop_id").bindparams(
                eta=eta, stop_id=stop["id"]
            )
        )
    db.commit()
