import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:frontend/core/models/trip_suggestion.dart';
import 'package:frontend/core/theme/routb_theme.dart';
import 'package:frontend/features/matching/presentation/suggestions_map.dart';

TripSuggestion _suggestion({
  required int tripId,
  required List<LatLng> routePoints,
}) => TripSuggestion(
  tripId: tripId,
  driverName: 'Carlos Chofer',
  origin: 'Centro',
  destination: 'UTB',
  direction: 'to_campus',
  departureDate: DateTime(2026, 11, 14),
  departureTime: '7:00 AM',
  availableSeats: 2,
  etaPickup: DateTime(2026, 11, 14, 7, 15),
  detourMinutes: 3,
  walkDistanceM: 120,
  score: 0.2,
  degraded: false,
  routePoints: routePoints,
);

void main() {
  testWidgets('pinta una ruta por sugerencia y el punto del pasajero', (
    tester,
  ) async {
    const routeA = <LatLng>[
      LatLng(10.4236, -75.5477),
      LatLng(10.371078, -75.466261),
    ];
    const routeB = <LatLng>[
      LatLng(10.4130, -75.5350),
      LatLng(10.371078, -75.466261),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: RoutbTheme.light(),
        home: Scaffold(
          body: SuggestionsMap(
            suggestions: <TripSuggestion>[
              _suggestion(tripId: 1, routePoints: routeA),
              _suggestion(tripId: 2, routePoints: routeB),
            ],
            passengerPoints: const <LatLng>[LatLng(10.42, -75.54)],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(PolylineLayer), findsNWidgets(2));
    expect(find.byType(MarkerLayer), findsOneWidget);
    final markers = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
    expect(markers.markers.single.point, const LatLng(10.42, -75.54));
  });

  testWidgets('sin sugerencias ni puntos no construye el mapa', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: RoutbTheme.light(),
        home: const Scaffold(
          body: SuggestionsMap(
            suggestions: <TripSuggestion>[],
            passengerPoints: <LatLng>[],
          ),
        ),
      ),
    );

    expect(find.byType(FlutterMap), findsNothing);
  });
}
