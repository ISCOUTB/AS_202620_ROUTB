import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/models/travel_time.dart';
import 'package:frontend/core/models/trip.dart';
import 'package:frontend/core/models/trip_request.dart';
import 'package:frontend/core/models/trip_status.dart';
import 'package:frontend/core/theme/routb_theme.dart';
import 'package:frontend/core/widgets/eta_label.dart';
import 'package:frontend/features/driver/widgets/driver_cards.dart';

/// Viaje del conductor con la lista de solicitudes indicada.
Trip _trip({
  required List<TripRequest> requests,
  int availableSeats = 2,
  int totalSeats = 4,
}) => Trip(
  id: 10,
  origin: 'Centro',
  destination: 'UTB',
  totalSeats: totalSeats,
  availableSeats: availableSeats,
  rawDeparture: '7:00 AM',
  departure: TravelTime.tryParse('7:00 AM'),
  departureDate: DateTime.now().add(const Duration(days: 1)),
  meetingPoint: 'Torre del Reloj',
  status: TripStatus.active,
  driverId: 1,
  driverName: 'Carlos Chofer',
  requests: requests,
);

/// Solicitud de cupo con los datos mínimos que pinta la tarjeta.
TripRequest _request({
  required int id,
  required String passengerName,
  required int seatCount,
  required SeatRequestStatus status,
}) => TripRequest(
  id: id,
  tripId: 10,
  passengerId: id,
  seatCount: seatCount,
  passengerName: passengerName,
  passengerPhone: '3001234567',
  status: status,
  createdAt: DateTime(2026, 10, 22, 8, 30),
);

Widget _app(Widget child) => MaterialApp(
  theme: RoutbTheme.light(),
  home: Scaffold(
    body: Padding(padding: const EdgeInsets.all(16), child: child),
  ),
);

RouteCard _routeCard(Trip trip) => RouteCard(
  trip: trip,
  selected: true,
  onSelect: () {},
  onOpenDetail: () {},
  onCancel: () {},
);

void main() {
  group('RequestTile · ETA por parada (G23)', () {
    testWidgets('muestra la hora estimada cuando el backend la envía', (
      tester,
    ) async {
      final request = TripRequest(
        id: 20,
        tripId: 10,
        passengerId: 20,
        seatCount: 1,
        passengerName: 'Ana Pasajera',
        passengerPhone: '',
        status: SeatRequestStatus.pending,
        createdAt: DateTime(2026, 10, 22, 8, 30),
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
        _app(
          RequestTile(
            request: request,
            trip: _trip(requests: <TripRequest>[request]),
            busy: false,
            onAccept: () {},
            onReject: () {},
          ),
        ),
      );

      expect(find.byType(EtaLabel), findsOneWidget);
      expect(find.textContaining('Recogida estimada'), findsOneWidget);
    });

    testWidgets('sin ETA no muestra la fila', (tester) async {
      final request = _request(
        id: 21,
        passengerName: 'Ana Pasajera',
        seatCount: 1,
        status: SeatRequestStatus.pending,
      );

      await tester.pumpWidget(
        _app(
          RequestTile(
            request: request,
            trip: _trip(requests: <TripRequest>[request]),
            busy: false,
            onAccept: () {},
            onReject: () {},
          ),
        ),
      );

      expect(find.byType(EtaLabel), findsNothing);
    });
  });

  group('RouteCard · resumen de solicitudes', () {
    testWidgets('sin solicitudes no muestra el resumen de confirmados', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_routeCard(_trip(requests: const []))));

      expect(find.textContaining('cupos confirmados'), findsNothing);
    });

    testWidgets('con solicitudes pendientes no muestra cupos confirmados', (
      tester,
    ) async {
      final trip = _trip(
        requests: [
          _request(
            id: 1,
            passengerName: 'Ana Pasajera',
            seatCount: 2,
            status: SeatRequestStatus.pending,
          ),
        ],
      );

      await tester.pumpWidget(_app(_routeCard(trip)));

      expect(find.text('1 solicitud'), findsOneWidget);
      expect(find.textContaining('cupos confirmados'), findsNothing);
      expect(find.text('AP'), findsNothing);
    });

    testWidgets('muestra el conteo y las iniciales de los confirmados', (
      tester,
    ) async {
      final trip = _trip(
        availableSeats: 1,
        requests: [
          _request(
            id: 1,
            passengerName: 'Ana Pasajera',
            seatCount: 2,
            status: SeatRequestStatus.accepted,
          ),
          _request(
            id: 2,
            passengerName: 'Luis Conductor',
            seatCount: 1,
            status: SeatRequestStatus.accepted,
          ),
          _request(
            id: 3,
            passengerName: 'Zoe Pendiente',
            seatCount: 1,
            status: SeatRequestStatus.pending,
          ),
        ],
      );

      await tester.pumpWidget(_app(_routeCard(trip)));

      expect(find.text('3 de 4 cupos confirmados'), findsOneWidget);
      // Una inicial por cupo confirmado: dos de Ana y una de Luis.
      expect(find.text('AP'), findsNWidgets(2));
      expect(find.text('LC'), findsOneWidget);
      // La solicitud pendiente no aporta nombres ni iniciales al resumen.
      expect(find.text('ZP'), findsNothing);
    });
  });
}
