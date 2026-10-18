import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

import 'package:frontend/core/map/place_locator.dart';
import 'package:frontend/core/theme/routb_theme.dart';
import 'package:frontend/core/widgets/route_map.dart';

void main() {
  testWidgets(
    'al volver a montar una vista previa conserva la coordenada geocodificada',
    (tester) async {
      final previousLocator = PlaceLocator.instance;
      final actualPoint = const LatLng(10.4011, -75.5122);
      final locator = PlaceLocator(
        client: MockClient((request) async {
          return http.Response(
            jsonEncode(<Map<String, String>>[
              <String, String>{'lat': '10.4011', 'lon': '-75.5122'},
            ]),
            200,
            headers: const <String, String>{'content-type': 'application/json'},
          );
        }),
        minInterval: Duration.zero,
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
