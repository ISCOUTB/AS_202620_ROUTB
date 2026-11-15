import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:frontend/core/models/my_request.dart';
import 'package:frontend/core/models/trip.dart';
import 'package:frontend/core/models/trip_suggestion.dart';

const List<Map<String, double>> _routeJson = <Map<String, double>>[
  <String, double>{'lat': 10.42, 'lng': -75.55},
  <String, double>{'lat': 10.40, 'lng': -75.50},
];

void main() {
  test('Trip.fromJson lee route_points', () {
    final trip = Trip.fromJson(<String, dynamic>{
      'id': 1,
      'origin': 'Centro',
      'destination': 'UTB',
      'total_seats': 4,
      'available_seats': 2,
      'departure_time': '7:00 AM',
      'status': 'active',
      'route_points': _routeJson,
    });

    expect(trip.routePoints, const <LatLng>[
      LatLng(10.42, -75.55),
      LatLng(10.40, -75.50),
    ]);
  });

  test('MyRequest.fromJson lee route_points', () {
    final request = MyRequest.fromJson(<String, dynamic>{
      'id': 7,
      'trip_id': 1,
      'status': 'accepted',
      'origin': 'Centro',
      'destination': 'UTB',
      'departure_time': '7:00 AM',
      'total_seats': 4,
      'available_seats': 2,
      'trip_status': 'active',
      'created_at': '2026-11-14T07:00:00',
      'route_points': _routeJson,
    });

    expect(request.routePoints.length, 2);
    expect(request.routePoints.first, const LatLng(10.42, -75.55));
  });

  test('TripSuggestion.fromJson lee route_points', () {
    final suggestion = TripSuggestion.fromJson(<String, dynamic>{
      'trip_id': 1,
      'driver_name': 'Carlos',
      'origin': 'Centro',
      'destination': 'UTB',
      'direction': 'to_campus',
      'departure_date': '2026-11-14',
      'departure_time': '7:00 AM',
      'available_seats': 2,
      'route_points': _routeJson,
    });

    expect(suggestion.routePoints.length, 2);
    expect(suggestion.routePoints.last, const LatLng(10.40, -75.50));
  });

  test('route_points incompletos se ignoran sin romper el parseo', () {
    final trip = Trip.fromJson(<String, dynamic>{
      'id': 1,
      'origin': 'Centro',
      'destination': 'UTB',
      'total_seats': 4,
      'available_seats': 2,
      'departure_time': '7:00 AM',
      'status': 'active',
      'route_points': <dynamic>[
        <String, dynamic>{'lat': 10.42},
        <String, dynamic>{'lat': 'no-numérico', 'lng': -75.5},
        <String, dynamic>{'lat': 10.40, 'lng': -75.50},
      ],
    });

    expect(trip.routePoints, const <LatLng>[LatLng(10.40, -75.50)]);
  });
}
