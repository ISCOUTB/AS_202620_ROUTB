import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/models/travel_time.dart';
import 'package:frontend/core/models/trip.dart';
import 'package:frontend/core/models/trip_status.dart';
import 'package:frontend/core/theme/routb_theme.dart';
import 'package:frontend/features/passenger/widgets/trip_card.dart';

Trip _trip({required int availableSeats, int totalSeats = 4}) => Trip(
  id: 1,
  origin: 'Centro',
  destination: 'UTB',
  totalSeats: totalSeats,
  availableSeats: availableSeats,
  rawDeparture: '7:00 AM',
  departure: TravelTime.tryParse('7:00 AM'),
  departureDate: DateTime.now().add(const Duration(days: 1)),
  meetingPoint: 'Torre del Reloj',
  status: TripStatus.active,
  driverId: 2,
  driverName: 'Luis Chofer',
  requests: const [],
);

Widget _app(Trip trip) => MaterialApp(
  theme: RoutbTheme.light(),
  home: Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: TripCard(trip: trip, onReserve: () {}),
    ),
  ),
);

void main() {
  group('TripCard · aviso de pocos cupos (G6)', () {
    testWidgets('con 1 cupo muestra el aviso', (tester) async {
      await tester.pumpWidget(_app(_trip(availableSeats: 1)));
      expect(find.text('¡Solo 1!'), findsOneWidget);
    });

    testWidgets('con 2 cupos muestra el aviso', (tester) async {
      await tester.pumpWidget(_app(_trip(availableSeats: 2)));
      expect(find.text('¡Solo 2!'), findsOneWidget);
    });

    testWidgets('con 3 o más cupos no muestra el aviso', (tester) async {
      await tester.pumpWidget(_app(_trip(availableSeats: 3)));
      expect(find.textContaining('¡Solo'), findsNothing);
    });

    testWidgets('sin cupos no muestra el aviso', (tester) async {
      await tester.pumpWidget(_app(_trip(availableSeats: 0)));
      expect(find.textContaining('¡Solo'), findsNothing);
    });
  });

  group('TripCard · viaje que ya salió', () {
    testWidgets('muestra el estado finalizado y no permite solicitar', (
      tester,
    ) async {
      final now = DateTime(2026, 11, 14, 12, 0);
      final trip = Trip(
        id: 1,
        origin: 'Centro',
        destination: 'UTB',
        totalSeats: 4,
        availableSeats: 2,
        rawDeparture: '7:30 AM',
        departure: TravelTime.tryParse('7:30 AM'),
        departureDate: DateTime(2026, 11, 14),
        meetingPoint: 'Torre del Reloj',
        status: TripStatus.active,
        driverId: 2,
        driverName: 'Luis Chofer',
        requests: const [],
      );
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: RoutbTheme.light(),
          home: Scaffold(
            body: TripCard(
              trip: trip,
              now: now,
              onReserve: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Viaje finalizado'), findsOneWidget);
      expect(find.text('Solicitar cupos'), findsNothing);

      await tester.tap(find.text('Viaje finalizado'));
      expect(tapped, isFalse);
    });
  });
}
