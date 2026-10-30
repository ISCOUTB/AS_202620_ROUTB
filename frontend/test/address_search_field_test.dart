import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/google_maps_service.dart';
import 'package:frontend/core/theme/routb_theme.dart';
import 'package:frontend/core/widgets/address_search_field.dart';
import 'package:latlong2/latlong.dart';

class _FakeGoogleMapsService extends GoogleMapsService {
  _FakeGoogleMapsService() : super(apiKey: 'test-key');

  @override
  Future<List<GooglePlaceSuggestion>> autocomplete(
    String query, {
    Future<void>? abortTrigger,
  }) async {
    return const <GooglePlaceSuggestion>[
      GooglePlaceSuggestion(
        placeId: 'manga',
        text: 'Manga, Cartagena',
        mainText: 'Manga',
        secondaryText: 'Cartagena',
      ),
      GooglePlaceSuggestion(
        placeId: 'turbaco',
        text: 'Turbaco, Bolívar',
        mainText: 'Turbaco',
        secondaryText: 'Bolívar',
      ),
    ];
  }

  @override
  Future<GooglePlaceDetails?> getPlaceDetails(
    String placeId, {
    Future<void>? abortTrigger,
  }) async {
    return switch (placeId) {
      'manga' => const GooglePlaceDetails(
        placeId: 'manga',
        formattedAddress: 'Manga, Cartagena',
        location: LatLng(10.413, -75.535),
      ),
      'turbaco' => const GooglePlaceDetails(
        placeId: 'turbaco',
        formattedAddress: 'Turbaco, Bolívar',
        location: LatLng(10.334, -75.416),
      ),
      _ => null,
    };
  }
}

void main() {
  testWidgets('solicita ubicación solo al pulsar y notifica el punto elegido', (
    tester,
  ) async {
    var locateCalls = 0;
    var clearCalls = 0;
    SelectedLocation? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: RoutbTheme.light(),
        home: Scaffold(
          body: AddressSearchField(
            locateCurrentPosition: () async {
              locateCalls += 1;
              return const SelectedLocation(
                lat: 10.4,
                lng: -75.5,
                addressText: 'Mi ubicación actual',
              );
            },
            onLocationSelected: (location) => selected = location,
            onLocationCleared: () {
              clearCalls += 1;
              selected = null;
            },
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

    // Si se escribe otra dirección, no se puede seguir enviando el punto
    // anterior solo porque todavía no se eligió una sugerencia nueva.
    await tester.enterText(find.byType(TextField), 'Nueva ubicación');
    await tester.pump();
    expect(clearCalls, 1);
    expect(selected, isNull);
  });

  testWidgets('si se deniega el permiso, mantiene disponible el pin manual', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: RoutbTheme.light(),
        home: Scaffold(
          body: AddressSearchField(
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

  testWidgets(
    'buscar deja las sugerencias visibles y solo confirma al tocarlas',
    (tester) async {
      SelectedLocation? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: RoutbTheme.light(),
          home: Scaffold(
            body: AddressSearchField(
              googleMapsService: _FakeGoogleMapsService(),
              locateCurrentPosition: () async => const SelectedLocation(
                lat: 4.6097,
                lng: -74.0817,
                addressText: 'Ubicación anterior',
              ),
              onLocationSelected: (location) => selected = location,
              onLocationCleared: () => selected = null,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Usar mi ubicación'));
      await tester.pumpAndSettle();
      expect(selected?.lat, 4.6097);

      await tester.enterText(find.byType(TextField), 'Turbaco');
      await tester.pump();
      expect(selected, isNull);

      await tester.tap(find.text('Buscar'));
      await tester.pumpAndSettle();
      // Escribir o buscar no confirma una ubicación por sí solo.
      expect(selected, isNull);

      await tester.tap(find.text('Turbaco, Bolívar'));
      await tester.pumpAndSettle();
      expect(selected?.lat, 10.334);
      expect(selected?.lng, -75.416);
      expect(selected?.addressText, 'Turbaco, Bolívar');
    },
  );

  testWidgets(
    'tocar el campo abre el menú y elegir un barrio confirma su punto',
    (tester) async {
      SelectedLocation? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: RoutbTheme.light(),
          home: Scaffold(
            body: AddressSearchField(
              onLocationSelected: (location) => selected = location,
              onLocationCleared: () => selected = null,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(find.text('Barrios de Cartagena'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Manga');
      await tester.pump();
      expect(selected, isNull);

      await tester.tap(find.widgetWithText(ListTile, 'Manga'));
      await tester.pumpAndSettle();
      expect(selected?.lat, 10.4130);
      expect(selected?.lng, -75.5350);
      expect(selected?.addressText, 'Manga, Cartagena');
    },
  );

  testWidgets('muestra Sin resultados cuando el texto no coincide', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: RoutbTheme.light(),
        home: Scaffold(body: AddressSearchField(onLocationSelected: (_) {})),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pump();

    expect(find.text('Sin resultados'), findsOneWidget);
    expect(find.text('Barrios de Cartagena'), findsNothing);
  });
}
