import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/google_maps_service.dart';
import 'package:frontend/core/theme/routb_theme.dart';
import 'package:frontend/core/widgets/address_search_field.dart';
<<<<<<< HEAD
import 'package:latlong2/latlong.dart';

class _FakeGoogleMapsService extends GoogleMapsService {
  _FakeGoogleMapsService() : super(apiKey: 'test-key');

  @override
  Future<List<GooglePlaceSuggestion>> autocomplete(String query) async {
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
  Future<GooglePlaceDetails?> getPlaceDetails(String placeId) async {
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
=======
import 'package:frontend/features/trips/data/geocode_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
>>>>>>> origin/master

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
    'buscar y elegir una sugerencia con el mapa oculto reemplaza la ubicación anterior',
    (tester) async {
<<<<<<< HEAD
=======
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final api = ApiClient(
        SessionStore(),
        client: MockClient((request) async {
          return http.Response(
            jsonEncode(<Map<String, Object>>[
              <String, Object>{
                'lat': 10.413,
                'lng': -75.535,
                'display_name': 'Manga, Cartagena',
                'source': 'nominatim',
              },
              <String, Object>{
                'lat': 10.334,
                'lng': -75.416,
                'display_name': 'Turbaco, Bolívar',
                'source': 'nominatim',
              },
            ]),
            200,
            headers: const <String, String>{'content-type': 'application/json'},
          );
        }),
      );

>>>>>>> origin/master
      SelectedLocation? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: RoutbTheme.light(),
          home: Scaffold(
            body: AddressSearchField(
<<<<<<< HEAD
              googleMapsService: _FakeGoogleMapsService(),
=======
              geocodeRepository: GeocodeRepository(api),
>>>>>>> origin/master
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
      // Al buscar toma el primer resultado y además permite tocar otro con el mapa cerrado.
      expect(selected?.lat, 10.413);

      await tester.tap(find.text('Turbaco, Bolívar'));
      await tester.pumpAndSettle();
      expect(selected?.lat, 10.334);
      expect(selected?.lng, -75.416);
      expect(selected?.addressText, 'Turbaco, Bolívar');
    },
  );
}
