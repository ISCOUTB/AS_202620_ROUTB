import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

import 'package:frontend/core/constants/zones.dart';
import 'package:frontend/core/map/place_locator.dart';
import 'package:frontend/core/network/google_maps_service.dart';

void main() {
  group('PlaceLocator', () {
    test('un texto vacío no llama a la red', () async {
      var calls = 0;
      final locator = PlaceLocator(
        client: MockClient((request) async {
          calls += 1;
          return http.Response('[]', 200);
        }),
        minInterval: Duration.zero,
      );

      expect(await locator.locate('  '), isNull);
      expect(calls, 0);
    });

    test('Nominatim gana cuando responde una coordenada', () async {
      final locator = PlaceLocator(
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
      );

      final point = await locator.locate('Manga');
      expect(point, const LatLng(10.4011, -75.5122));
    });

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

      final point = await locator.locate('Centro');
      expect(point, Zones.pointOf(Zones.byName('Centro')!));
    });

    test('sin Nominatim ni catálogo no inventa la universidad', () async {
      final locator = PlaceLocator(
        client: MockClient((request) async => http.Response('[]', 200)),
        minInterval: Duration.zero,
      );

      expect(await locator.locate('Calle inventada 99'), isNull);
    });

    test('cachea Nominatim para no repetir la misma búsqueda', () async {
      var calls = 0;
      final locator = PlaceLocator(
        client: MockClient((request) async {
          calls += 1;
          return http.Response(
            jsonEncode(<Map<String, String>>[
              <String, String>{'lat': '10.42', 'lon': '-75.54'},
            ]),
            200,
          );
        }),
        minInterval: Duration.zero,
      );

      await locator.locate('UTB');
      await locator.locate('utb');
      expect(calls, 1);
    });

    test('OSRM devuelve la polilínea en latitud, longitud', () async {
      final locator = PlaceLocator(
        client: MockClient((request) async {
          expect(request.url.host, 'router.project-osrm.org');
          return http.Response(
            jsonEncode(<String, Object>{
              'routes': <Map<String, Object>>[
                <String, Object>{
                  'geometry': <String, Object>{
                    'coordinates': <List<double>>[
                      <double>[-75.5477, 10.4236],
                      <double>[-75.5440, 10.4216],
                    ],
                  },
                },
              ],
            }),
            200,
          );
        }),
        minInterval: Duration.zero,
      );

      final road = await locator.route(
        const LatLng(10.4236, -75.5477),
        const LatLng(10.4216, -75.5440),
      );
      expect(road, <LatLng>[
        const LatLng(10.4236, -75.5477),
        const LatLng(10.4216, -75.5440),
      ]);
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
}
