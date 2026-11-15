import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/models/travel_time.dart';
import 'package:frontend/core/models/trip.dart';
import 'package:frontend/core/models/trip_request.dart';
import 'package:frontend/core/models/trip_status.dart';
import 'package:frontend/core/services/whatsapp_launcher.dart';
import 'package:frontend/core/theme/routb_theme.dart';
import 'package:frontend/core/widgets/eta_label.dart';
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
      // El teléfono es privado mientras la solicitud está pendiente.
      expect(find.textContaining('3001234567'), findsNothing);

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

    testWidgets(
      'no muestra el teléfono ni WhatsApp antes de aceptar la solicitud',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showRequestPreviewSheet(
                  context: context,
                  trip: testTrip,
                  request: testRequest,
                  onAccept: () {},
                  onReject: () {},
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Abrir'));
        await settle(tester);

        expect(find.textContaining('3001234567'), findsNothing);
        expect(find.byType(WhatsAppButton), findsNothing);
        expect(find.text('Escribir por WhatsApp'), findsNothing);
        expect(
          find.text(
            'El teléfono del pasajero se comparte cuando aceptes la solicitud.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('muestra la hora estimada de recogida por parada (G23)', (
      tester,
    ) async {
      final requestWithEta = TripRequest(
        id: 27,
        tripId: 10,
        passengerId: 7,
        seatCount: 1,
        passengerName: 'Ana Pasajera',
        passengerPhone: '',
        status: SeatRequestStatus.pending,
        createdAt: DateTime(2026, 10, 22, 9),
        stops: <TripRequestStop>[
          TripRequestStop(
            seats: 1,
            placeType: 'door',
            addressText: 'Manga Callejón Trébol',
            etaEstimated: DateTime(2026, 11, 14, 12, 45),
          ),
        ],
      );

      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showRequestPreviewSheet(
                context: context,
                trip: testTrip,
                request: requestWithEta,
                onAccept: () {},
                onReject: () {},
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir'));
      await settle(tester);

      expect(find.byType(EtaLabel), findsOneWidget);
      expect(find.textContaining('Recogida estimada'), findsOneWidget);
    });

    testWidgets('sin ETA no agrega una fila vacía en la hoja', (tester) async {
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showRequestPreviewSheet(
                context: context,
                trip: testTrip,
                request: testRequest,
                onAccept: () {},
                onReject: () {},
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir'));
      await settle(tester);

      expect(find.byType(EtaLabel), findsNothing);
    });

    testWidgets('oculta WhatsApp cuando el pasajero no tiene teléfono', (
      tester,
    ) async {
      final requestWithoutPhone = TripRequest(
        id: 26,
        tripId: 10,
        passengerId: 6,
        seatCount: 1,
        passengerName: 'Sin Teléfono',
        passengerPhone: '',
        status: SeatRequestStatus.pending,
        createdAt: DateTime(2026, 10, 22, 9),
      );

      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showRequestPreviewSheet(
                context: context,
                trip: testTrip,
                request: requestWithoutPhone,
                onAccept: () {},
                onReject: () {},
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir'));
      await settle(tester);

      expect(find.byType(WhatsAppButton), findsNothing);
      expect(find.text('Escribir por WhatsApp'), findsNothing);
    });
  });
}
