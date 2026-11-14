import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:frontend/core/theme/routb_theme.dart';
import 'package:frontend/core/widgets/route_map.dart';
import 'package:frontend/features/driver/widgets/publish_route_sheet.dart';

void main() {
  testWidgets('la vista previa de publicación reutiliza el mapa del viaje', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: RoutbTheme.light(),
        home: const Scaffold(
          body: PublishRouteMapPreview(
            origin: 'Manga',
            destination: 'UTB',
            originCoordinate: LatLng(10.413, -75.535),
            destinationCoordinate: LatLng(10.371078, -75.466261),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(RouteMap), findsOneWidget);
    final markers = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
    expect(markers.markers.length, 2);
  });
}
