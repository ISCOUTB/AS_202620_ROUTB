import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/session_store.dart';
import 'package:frontend/core/theme/routb_theme.dart';
import 'package:frontend/core/widgets/address_search_field.dart';
import 'package:frontend/features/trips/data/geocode_repository.dart';

void main() {
  testWidgets('solicita ubicación solo al pulsar y notifica el punto elegido', (
    tester,
  ) async {
    var locateCalls = 0;
    SelectedLocation? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: RoutbTheme.light(),
        home: Scaffold(
          body: AddressSearchField(
            geocodeRepository: GeocodeRepository(ApiClient(SessionStore())),
            locateCurrentPosition: () async {
              locateCalls += 1;
              return const SelectedLocation(
                lat: 10.4,
                lng: -75.5,
                addressText: 'Mi ubicación actual',
              );
            },
            onLocationSelected: (location) => selected = location,
          ),
        ),
      ),
    );

    expect(locateCalls, 0);
    await tester.tap(find.text('Usar mi ubicación'));
    await tester.pumpAndSettle();

    expect(locateCalls, 1);
    expect(selected?.lat, 10.4);
    expect(selected?.lng, -75.5);
  });

  testWidgets('si se deniega el permiso, mantiene disponible el pin manual', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: RoutbTheme.light(),
        home: Scaffold(
          body: AddressSearchField(
            geocodeRepository: GeocodeRepository(ApiClient(SessionStore())),
            locateCurrentPosition: () async => throw Exception('denied'),
            onLocationSelected: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Usar mi ubicación'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'No se pudo obtener tu ubicación. Puedes ajustar el pin manualmente.',
      ),
      findsOneWidget,
    );
    expect(find.text('Ajustar ubicación en el mapa'), findsOneWidget);
  });
}
