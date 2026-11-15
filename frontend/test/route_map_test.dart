import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:frontend/core/map/place_locator.dart';
import 'package:frontend/core/network/google_maps_service.dart';
import 'package:frontend/core/theme/routb_theme.dart';
import 'package:frontend/core/widgets/route_map.dart';

class _FakeGeocoder extends GoogleMapsService {
  _FakeGeocoder(this.point) : super(apiKey: 'test-key');

  final LatLng point;

  @override
  Future<LatLng?> geocodeAddress(String query) async {
    return query.trim().toLowerCase() == 'manga' ? point : null;
  }
}

void main() {
  testWidgets(
    'al volver a montar una vista previa conserva la coordenada geocodificada',
    (tester) async {
      final previousLocator = PlaceLocator.instance;
      final actualPoint = const LatLng(10.4011, -75.5122);
      final locator = PlaceLocator(
        googleMapsService: _FakeGeocoder(actualPoint),
      );
      await locator.locate('Manga');
      PlaceLocator.instance = locator;

      Future<void> showMap(Key key) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: RoutbTheme.light(),
            home: Scaffold(
              body: RouteMap(
                key: key,
                origin: 'Manga',
                destination: 'UTB',
                animateRoute: false,
              ),
            ),
          ),
        );
        await tester.pump();

        final markerLayer = tester.widget<MarkerLayer>(
          find.byType(MarkerLayer),
        );
        expect(
          markerLayer.markers.map((marker) => marker.point),
          contains(actualPoint),
        );
      }

      try {
        await showMap(const ValueKey<String>('first-preview'));
        // Simula que la pantalla que contiene el preview se reconstruye y
        // Flutter crea un RouteMap nuevo para el mismo trayecto.
        await showMap(const ValueKey<String>('rebuilt-preview'));
      } finally {
        PlaceLocator.instance = previousLocator;
      }
    },
  );

  testWidgets('RouteMap dibuja la geometría exacta que entrega el backend', (
    tester,
  ) async {
    const geometry = <LatLng>[
      LatLng(10.4236, -75.5477),
      LatLng(10.4100, -75.5300),
      LatLng(10.371078, -75.466261),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: RoutbTheme.light(),
        home: const Scaffold(
          body: RouteMap(
            origin: 'Centro',
            destination: 'UTB',
            routePoints: geometry,
            animateRoute: false,
          ),
        ),
      ),
    );
    await tester.pump();

    final line = tester.widget<PolylineLayer>(find.byType(PolylineLayer));
    expect(line.polylines.single.points, geometry);

    final markerLayer = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
    expect(markerLayer.markers.first.point, geometry.first);
    expect(markerLayer.markers.last.point, geometry.last);
  });

  testWidgets(
    'RouteMap dibuja todas las paradas intermedias pasadas en waypoints',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: RoutbTheme.light(),
          home: const Scaffold(
            body: RouteMap(
              origin: 'Bocagrande',
              destination: 'UTB',
              waypoints: <String>['Manga', 'Getsemaní'],
              animateRoute: false,
            ),
          ),
        ),
      );
      await tester.pump();

      final markerLayer = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
      // Origen, destino y 2 paradas intermedias = 4 marcadores en total
      expect(markerLayer.markers.length, equals(4));
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('2 paradas'), findsOneWidget);
    },
  );
}
