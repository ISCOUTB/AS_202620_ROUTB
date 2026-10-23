import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/models/travel_time.dart';
import 'package:frontend/core/models/trip.dart';
import 'package:frontend/core/models/trip_request.dart';
import 'package:frontend/core/models/trip_status.dart';
import 'package:frontend/core/theme/routb_theme.dart';
import 'package:frontend/features/driver/widgets/driver_cards.dart';
import 'package:frontend/features/driver/widgets/request_preview_sheet.dart';

void main() {
  final testTrip = Trip(
    id: 10,
    origin: 'Centro',
    destination: 'UTB',
    totalSeats: 4,
    availableSeats: 3,
    rawDeparture: '7:00 AM',
    departure: TravelTime.tryParse('7:00 AM'),
    departureDate: DateTime(2026, 10, 25),
    meetingPoint: 'Torre del Reloj',
    status: TripStatus.active,
    direction: 'to_campus',
    driverId: 1,
    driverName: 'Carlos Chofer',
    requests: const <TripRequest>[],
  );

  final testRequest = TripRequest(
    id: 25,
    tripId: 10,
    passengerId: 5,
    seatCount: 1,
    passengerName: 'Ana Pasajera',
    passengerPhone: '3001234567',
    status: SeatRequestStatus.pending,
    createdAt: DateTime(2026, 10, 22, 8, 30),
    stops: const <TripRequestStop>[
      TripRequestStop(
        seats: 1,
        placeType: 'door',
        addressText: 'Manga Callejón Trébol',
      ),
    ],
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  Widget wrap(Widget child) => MaterialApp(
    theme: RoutbTheme.light(),
    home: Scaffold(body: child),
  );

  group('RequestTile', () {
    testWidgets('muestra opción de previsualizar ruta y responde al toque', (
      tester,
    ) async {
      var previewOpened = false;

      await tester.pumpWidget(
        wrap(
          RequestTile(
            request: testRequest,
            trip: testTrip,
            busy: false,
            onTapPreview: () => previewOpened = true,
            onAccept: () {},
            onReject: () {},
          ),
        ),
      );
      await settle(tester);

      expect(find.text('Ana Pasajera'), findsOneWidget);
      expect(find.text('Previsualizar ruta'), findsOneWidget);

      await tester.tap(find.text('Previsualizar ruta'));
      await tester.pump();

      expect(previewOpened, isTrue);
    });
  });

  group('showRequestPreviewSheet', () {
    testWidgets(
      'abre la hoja con el mapa, detalle y acciones de aceptar y rechazar',
      (tester) async {
        var accepted = false;

        await tester.pumpWidget(
          wrap(
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showRequestPreviewSheet(
                  context: context,
                  trip: testTrip,
                  request: testRequest,
                  onAccept: () => accepted = true,
                  onReject: () {},
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Abrir'));
        await settle(tester);

        expect(find.text('Solicitud de Ana Pasajera'), findsOneWidget);
        expect(find.text('Centro → UTB'), findsOneWidget);
        expect(find.text('Manga Callejón Trébol'), findsOneWidget);
        expect(find.text('Aceptar cupo'), findsOneWidget);
        expect(find.text('Rechazar'), findsOneWidget);

        // Probar aceptar
        await tester.tap(find.text('Aceptar cupo'));
        await settle(tester);

        expect(accepted, isTrue);
        expect(find.text('Solicitud de Ana Pasajera'), findsNothing);
      },
    );

    testWidgets('rechazar en la hoja llama a onReject y cierra la hoja', (
      tester,
    ) async {
      var rejected = false;

      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showRequestPreviewSheet(
                context: context,
                trip: testTrip,
                request: testRequest,
                onAccept: () {},
                onReject: () => rejected = true,
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir'));
      await settle(tester);

      await tester.tap(find.text('Rechazar'));
      await settle(tester);

      expect(rejected, isTrue);
      expect(find.text('Solicitud de Ana Pasajera'), findsNothing);
    });
  });
}
