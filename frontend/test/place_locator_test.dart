import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/constants/zones.dart';
import 'package:frontend/core/map/place_locator.dart';
import 'package:frontend/core/network/google_maps_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

<<<<<<< HEAD
class _FakeGoogleMapsService extends GoogleMapsService {
  _FakeGoogleMapsService({this.geocodeResult, this.routeResult})
    : super(apiKey: 'test-key');

  final LatLng? geocodeResult;
  final GoogleRouteResult? routeResult;
  int geocodeCalls = 0;
  int routeCalls = 0;

  @override
  Future<LatLng?> geocodeAddress(String query) async {
    geocodeCalls += 1;
    return geocodeResult;
  }

  @override
  Future<GoogleRouteResult?> computeRoute({
    required LatLng origin,
    required LatLng destination,
    List<LatLng> waypoints = const <LatLng>[],
    bool optimizeWaypointOrder = true,
  }) async {
    routeCalls += 1;
    return routeResult;
  }
}
=======
import 'package:frontend/core/constants/zones.dart';
import 'package:frontend/core/map/place_locator.dart';
import 'package:frontend/core/network/google_maps_service.dart';
>>>>>>> origin/master

void main() {
  group('PlaceLocator', () {
    test('un texto vacío no llama a la red', () async {
      final google = _FakeGoogleMapsService();
      final locator = PlaceLocator(googleMapsService: google);

      expect(await locator.locate('  '), isNull);
      expect(google.geocodeCalls, 0);
    });

    test('Google gana cuando responde una coordenada', () async {
      const expected = LatLng(10.4011, -75.5122);
      final locator = PlaceLocator(
<<<<<<< HEAD
        googleMapsService: _FakeGoogleMapsService(geocodeResult: expected),
=======
        client: MockClient((request) async {
          expect(request.url.host, 'nominatim.openstreetmap.org');
          expect(request.headers['user-agent'], PlaceLocator.userAgent);
          expect(request.url.queryParameters['q'], contains('Manga'));
          expect(request.url.queryParameters['q'], contains('Cartagena'));
          return http.Response(
            jsonEncode(<Map<String, String>>[
              <String, String>{'lat': '10.4011', 'lon': '-75.5122'},
            ]),
            200,
            headers: const <String, String>{'content-type': 'application/json'},
          );
        }),
        minInterval: Duration.zero,
>>>>>>> origin/master
      );

      final point = await locator.locate('Manga');
      expect(point, expected);
    });

<<<<<<< HEAD
    test('si Google no encuentra, usa el catálogo', () async {
      final locator = PlaceLocator(googleMapsService: _FakeGoogleMapsService());
=======
    test('Turbaco se busca en Bolívar con sesgo de viewbox sin bloquear otras zonas', () async {
      final locator = PlaceLocator(
        client: MockClient((request) async {
          expect(
            request.url.queryParameters['q'],
            'Turbaco, Bolívar, Colombia',
          );
          expect(request.url.queryParameters['viewbox'], isNotEmpty);
          expect(request.url.queryParameters.containsKey('bounded'), isFalse);
          return http.Response(
            jsonEncode(<Map<String, String>>[
              <String, String>{'lat': '10.334', 'lon': '-75.416'},
            ]),
            200,
          );
        }),
        minInterval: Duration.zero,
      );

      expect(await locator.locate('Turbaco'), const LatLng(10.334, -75.416));
    });

    test('si Nominatim no encuentra, usa el catálogo', () async {
      final locator = PlaceLocator(
        client: MockClient((request) async => http.Response('[]', 200)),
        minInterval: Duration.zero,
      );
>>>>>>> origin/master

      final point = await locator.locate('Centro');
      expect(point, Zones.pointOf(Zones.byName('Centro')!));
    });

    test('sin Google ni catálogo no inventa la universidad', () async {
      final locator = PlaceLocator(googleMapsService: _FakeGoogleMapsService());

      expect(await locator.locate('Calle inventada 99'), isNull);
    });

    test(
      'cachea la geocodificación para no repetir la misma búsqueda',
      () async {
        final google = _FakeGoogleMapsService(
          geocodeResult: const LatLng(10.42, -75.54),
        );
        final locator = PlaceLocator(googleMapsService: google);

        await locator.locate('UTB');
        await locator.locate('utb');
        expect(google.geocodeCalls, 1);
      },
    );

    test('Google Routes devuelve la polilínea', () async {
      const route = <LatLng>[
        LatLng(10.4236, -75.5477),
        LatLng(10.4216, -75.5440),
      ];
      final locator = PlaceLocator(
        googleMapsService: _FakeGoogleMapsService(
          routeResult: const GoogleRouteResult(
            durationSeconds: 600,
            distanceMeters: 4000,
            polyline: route,
          ),
        ),
      );

      final road = await locator.route(
        const LatLng(10.4236, -75.5477),
        const LatLng(10.4216, -75.5440),
      );
      expect(road, route);
    });
  });

  group('PlaceLocator.catalogPoint', () {
    test('resuelve un barrio conocido y deja pasar el resto', () {
      expect(
        PlaceLocator.catalogPoint('Getsemaní'),
        Zones.pointOf(Zones.byName('Getsemaní')!),
      );
      expect(PlaceLocator.catalogPoint('Plaza de la Aduana'), isNull);
    });
  });

  group('GoogleMapsService.decodePolyline', () {
    test('decodifica correctamente coordenadas sin desbordar el hemisferio', () {
      const encoded =
          'kph~@nxvkMc@GGEASE]]BSCo@Yi@hAkAo@g@SqCc@yDgAmCgASGgCMr@cMf@oGH{A`@{DBsD^wIV}DFq@|@kDTuAFyBHqCJqDDg@Nw@Hw@P_A`@eBf@oA}CcBs@OkBIkDYmDOcJSw@E[@i@g@sA{@o@O|DaDz@u@t@w@_AmAv@k@Za@Z{@Le@n@qD`@qB?WWg@sK_Po@kArSuQfBgAhD}CnBeCZc@zEdElHbGh@n@xAdCfCvE^U';
      final points = GoogleMapsService.decodePolyline(encoded);

      expect(points, isNotEmpty);
      for (final p in points) {
        expect(p.latitude, inInclusiveRange(-90.0, 90.0));
        expect(p.longitude, inInclusiveRange(-180.0, 180.0));
      }
      expect(points.first.latitude, closeTo(10.37, 0.05));
      expect(points.last.latitude, closeTo(10.37, 0.05));
    });
  });
<<<<<<< HEAD

  group('GoogleMapsService.computeRoute', () {
    test(
      'envía optimizeWaypointOrder cuando hay más de una parada intermedia',
      () async {
        late Map<String, dynamic> capturedBody;
        late Map<String, String> capturedHeaders;

        final service = GoogleMapsService(
          apiKey: 'test-key',
          client: MockClient((request) async {
            expect(request.url.host, 'routes.googleapis.com');
            capturedHeaders = request.headers;
            capturedBody = jsonDecode(request.body) as Map<String, dynamic>;

            return http.Response(
              jsonEncode({
                'routes': [
                  {
                    'duration': '1200s',
                    'distanceMeters': 8500,
                    'polyline': {
                      'encodedPolyline': '_p~iF~ps|U_ulLnnqC_mqNvxq`@',
                    },
                    'optimizedIntermediateWaypointIndex': [1, 0],
                  },
                ],
              }),
              200,
            );
          }),
        );

        final result = await service.computeRoute(
          origin: const LatLng(10.40, -75.50),
          destination: const LatLng(10.45, -75.55),
          waypoints: const [LatLng(10.41, -75.51), LatLng(10.43, -75.53)],
        );

        expect(result, isNotNull);
        expect(capturedBody['optimizeWaypointOrder'], isTrue);
        expect(capturedBody['intermediates'], hasLength(2));
        expect(
          capturedHeaders['X-Goog-FieldMask'],
          contains('routes.optimizedIntermediateWaypointIndex'),
        );
        expect(result!.optimizedWaypointOrder, equals([1, 0]));
        expect(result.durationSeconds, 1200);
        expect(result.distanceMeters, 8500);
      },
    );

    test(
      'no envía optimizeWaypointOrder cuando optimizeWaypointOrder es false',
      () async {
        late Map<String, dynamic> capturedBody;

        final service = GoogleMapsService(
          apiKey: 'test-key',
          client: MockClient((request) async {
            capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode({
                'routes': [
                  {
                    'duration': '600s',
                    'distanceMeters': 4000,
                    'polyline': {'encodedPolyline': ''},
                  },
                ],
              }),
              200,
            );
          }),
        );

        final result = await service.computeRoute(
          origin: const LatLng(10.40, -75.50),
          destination: const LatLng(10.45, -75.55),
          waypoints: const [LatLng(10.41, -75.51), LatLng(10.43, -75.53)],
          optimizeWaypointOrder: false,
        );

        expect(result, isNotNull);
        expect(capturedBody.containsKey('optimizeWaypointOrder'), isFalse);
      },
    );
  });
=======
>>>>>>> origin/master
}
