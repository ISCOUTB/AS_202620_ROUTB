import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/models/travel_time.dart';
import 'package:frontend/core/models/trip.dart';
import 'package:frontend/core/models/trip_status.dart';
import 'package:frontend/core/theme/routb_theme.dart';
import 'package:frontend/features/passenger/widgets/trip_card.dart';
import 'package:frontend/features/passenger/widgets/vehicle_illustration.dart';

Trip _trip({
  required int availableSeats,
  int totalSeats = 4,
  String? vehicleInfo,
  String driverName = 'Luis Chofer',
}) => Trip(
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
  driverName: driverName,
  vehicleInfo: vehicleInfo,
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

class _MissingIllustration extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) {
    if (key == VehicleIllustration.asset) {
      return Future.error(FlutterError('Ilustración ausente'));
    }
    return rootBundle.load(key);
  }
}

void main() {
  testWidgets('muestra completo el nombre largo del conductor', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const name = 'María Fernanda del Carmen González de la Espriella';
    await tester.pumpWidget(_app(_trip(availableSeats: 2, driverName: name)));
    final nameText = tester.renderObject<RenderParagraph>(find.text(name));
    expect(nameText.didExceedMaxLines, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'usa una sola ilustración local con y sin ficha en pantalla estrecha',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      expect(
        (await rootBundle.load(VehicleIllustration.asset)).lengthInBytes,
        greaterThan(0),
      );
      for (final info in [
        null,
        'Chevrolet Spark · Gris (ABC-123)',
        'BYD Dolphin Mini',
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: RoutbTheme.dark(),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: TripCard(
                    trip: _trip(availableSeats: 2, vehicleInfo: info),
                    onReserve: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        final image = tester.widget<Image>(
          find.descendant(
            of: find.byType(VehicleIllustration),
            matching: find.byType(Image),
          ),
        );
        expect(
          (image.image as AssetImage).assetName,
          VehicleIllustration.asset,
        );
        expect(image.fit, BoxFit.contain);
        if (info != null) expect(find.text(info), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('un fallo de imagen conserva la acción de solicitar', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: RoutbTheme.light(),
        home: DefaultAssetBundle(
          bundle: _MissingIllustration(),
          child: Scaffold(
            body: TripCard(
              trip: _trip(availableSeats: 2),
              onReserve: () => tapped = true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.directions_car_outlined), findsOneWidget);
    await tester.tap(find.text('Solicitar cupos'));
    expect(tapped, isTrue);
  });

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
