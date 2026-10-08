import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/app/dependencies.dart';
import 'package:frontend/core/models/my_request.dart';
import 'package:frontend/core/models/user_role.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/session_store.dart';
import 'package:frontend/core/theme/routb_theme.dart';
import 'package:frontend/core/theme/theme_controller.dart';
import 'package:frontend/core/widgets/route_map.dart';
import 'package:frontend/features/auth/data/auth_repository.dart';
import 'package:frontend/features/passenger/screens/my_trip_screen.dart';
import 'package:frontend/features/passenger/screens/passenger_screen.dart';
import 'package:frontend/features/passenger/widgets/my_trip_card.dart';
import 'package:frontend/features/trips/data/geocode_repository.dart';
import 'package:frontend/features/trips/data/trip_repository.dart';

/// Tamaños de móvil que se comprueban.
///
/// 320 es un teléfono estrecho, 360 el más común en Android y 390/844 un iPhone.
/// Los tres entran en la prueba porque los desbordes de `Row` solo aparecen en
/// uno de ellos según qué texto haya en pantalla.
const List<Size> _phoneSizes = <Size>[
  Size(320, 568),
  Size(360, 640),
  Size(390, 844),
];

/// Un viaje en JSON, tal como lo devuelve `GET /trips/`.
Map<String, dynamic> _tripJson({String? myStatus}) => <String, dynamic>{
  'id': 1,
  'origin': 'Getsemaní',
  'destination': 'UTB',
  'total_seats': 4,
  'available_seats': 1,
  'departure_time': '7:00 AM',
  'status': 'active',
  'driver_id': 2,
  'driver_name': 'Luis Chofer',
  'my_request_status': ?myStatus,
};

/// Una solicitud propia en JSON, tal como la devuelve `GET /requests/me`.
Map<String, dynamic> _myRequestJson({
  String status = 'accepted',
  String tripStatus = 'active',
}) => <String, dynamic>{
  'id': 7,
  'status': status,
  'created_at': '2026-09-30T14:05:00',
  'trip_id': 1,
  'origin': 'Getsemaní',
  'destination': 'UTB',
  'departure_time': '7:00 AM',
  'total_seats': 4,
  'available_seats': 1,
  'trip_status': tripStatus,
  'driver_name': 'Luis Chofer',
  'driver_phone': '3015550002',
};

/// Respuestas de la API para las rutas que usa el modo pasajero.
List<({String path, Object body, int status})> _routes({
  List<Map<String, dynamic>> trips = const <Map<String, dynamic>>[],
  List<Map<String, dynamic>> myRequests = const <Map<String, dynamic>>[],
  bool requestsMeMissing = false,
  bool deleteFails = false,
}) => <({String path, Object body, int status})>[
  (
    path: '/trips/',
    body: trips.isEmpty ? <Map<String, dynamic>>[] : trips,
    status: 200,
  ),
  if (requestsMeMissing)
    (
      path: '/requests/me',
      body: <String, dynamic>{'detail': 'Not Found'},
      status: 404,
    )
  else
    (path: '/requests/me', body: myRequests, status: 200),
  (
    path: '/requests/7',
    body: deleteFails
        ? <String, dynamic>{'detail': 'Solo puedes retirar tu propia solicitud'}
        : '',
    status: deleteFails ? 403 : 204,
  ),
];

/// Monta las dependencias reales sobre un cliente que responde con [routes].
RoutbDependencies _dependencies(
  List<({String path, Object body, int status})> routes,
) {
  final session = SessionStore();
  final client = MockClient((request) async {
    final path = request.url.path;
    for (final route in routes) {
      if (path == route.path) {
        return http.Response(
          jsonEncode(route.body),
          route.status,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }
    }
    return http.Response('{"detail":"Not Found"}', 404);
  });

  final api = ApiClient(session, client: client);
  return RoutbDependencies(
    session: session,
    auth: AuthRepository(api, session),
    geocode: GeocodeRepository(api),
    trips: TripRepository(api),
    theme: ThemeController(session),
  );
}

/// Monta [child] con el tema de ROUTB dentro de una pantalla de móvil.
Widget _app(Widget child) =>
    MaterialApp(theme: RoutbTheme.light(), home: child);

/// Fija el tamaño de pantalla y devuelve el tamaño logical del dispositivo.
Future<Size> _usePhone(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  return size;
}

/// Deja correr los cuadros que necesitan las peticiones y las animaciones.
///
/// No se usa `pumpAndSettle` porque el punto del trayecto y los skeletons
/// animan sin parar.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

/// Baja del todo en el `ListView` de la pantalla.
///
/// El `ListView` es perezoso: en un móvil de 568 px de alto el botón de cancelar
/// queda fuera de la ventana y ni siquiera se construye, así que hay que
/// desplazarlo para poder buscarlo.
Future<void> _scrollToEnd(WidgetTester tester) async {
  await tester.drag(find.byType(ListView).last, const Offset(0, -600));
  await _settle(tester);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('Buscador del pasajero', () {
    testWidgets('el mapa y el buscador caben en un móvil estrecho', (
      tester,
    ) async {
      for (final size in _phoneSizes) {
        await _usePhone(tester, size);
        final dependencies = _dependencies(
          _routes(trips: <Map<String, dynamic>>[_tripJson()]),
        );
        addTearDown(dependencies.dispose);

        await tester.pumpWidget(
          _app(
            RoutbScopeDependencies(
              dependencies: dependencies,
              child: PassengerScreen(
                account: const Account(
                  token: 't',
                  name: 'Ana',
                  role: UserRole.passenger,
                ),
              ),
            ),
          ),
        );
        await _settle(tester);

        // El mapa compacto y el botón de hoja están en pantalla.
        expect(find.byType(RouteMap), findsOneWidget, reason: '$size');
        expect(find.text('Abrir mapa'), findsOneWidget, reason: '$size');
      }
    });

    testWidgets('la tarjeta de mi viaje aparece con la lista vacía', (
      tester,
    ) async {
      // El caso que la justifica: con el último cupo tomado, `GET /trips/`
      // devuelve cero viajes pero la solicitud sigue viva.
      await _usePhone(tester, const Size(360, 640));
      final dependencies = _dependencies(
        _routes(
          trips: const <Map<String, dynamic>>[],
          myRequests: <Map<String, dynamic>>[_myRequestJson()],
        ),
      );
      addTearDown(dependencies.dispose);

      await tester.pumpWidget(
        _app(
          RoutbScopeDependencies(
            dependencies: dependencies,
            child: PassengerScreen(
              account: const Account(
                token: 't',
                name: 'Ana',
                role: UserRole.passenger,
              ),
            ),
          ),
        ),
      );
      await _settle(tester);

      expect(
        find.text(
          'Todavía no hay ningún viaje publicado. Vuelve en un '
          'ratito o crea el tuyo como conductor.',
        ),
        findsOneWidget,
      );
      expect(find.byType(MyTripCard), findsOneWidget);
      expect(find.text('Cupo confirmado'), findsOneWidget);
      expect(find.textContaining('Getsemaní → UTB'), findsWidgets);
    });

    testWidgets('la tarjeta desaparece cuando la solicitud ya no está viva', (
      tester,
    ) async {
      await _usePhone(tester, const Size(360, 640));
      final dependencies = _dependencies(
        _routes(
          trips: <Map<String, dynamic>>[_tripJson()],
          myRequests: <Map<String, dynamic>>[
            _myRequestJson(status: 'rejected'),
          ],
        ),
      );
      addTearDown(dependencies.dispose);

      await tester.pumpWidget(
        _app(
          RoutbScopeDependencies(
            dependencies: dependencies,
            child: PassengerScreen(
              account: const Account(
                token: 't',
                name: 'Ana',
                role: UserRole.passenger,
              ),
            ),
          ),
        ),
      );
      await _settle(tester);

      expect(find.byType(MyTripCard), findsNothing);
    });

    testWidgets('la hoja del mapa se abre y muestra el trayecto', (
      tester,
    ) async {
      await _usePhone(tester, const Size(360, 640));
      final dependencies = _dependencies(
        _routes(trips: <Map<String, dynamic>>[_tripJson()]),
      );
      addTearDown(dependencies.dispose);

      await tester.pumpWidget(
        _app(
          RoutbScopeDependencies(
            dependencies: dependencies,
            child: PassengerScreen(
              account: const Account(
                token: 't',
                name: 'Ana',
                role: UserRole.passenger,
              ),
            ),
          ),
        ),
      );
      await _settle(tester);

      await tester.tap(find.text('Abrir mapa'));
      await _settle(tester);

      // El mapa de la hoja es más alto que el compacto del buscador.
      expect(find.text('Trayecto estimado'), findsOneWidget);
      final compact = tester.getSize(find.byType(RouteMap).first).height;
      final sheet = tester.getSize(find.byType(RouteMap).last).height;
      expect(sheet, greaterThan(compact));
    });
  });

  group('MiTripScreen', () {
    testWidgets('muestra el trayecto, el conductor y el botón de cancelar', (
      tester,
    ) async {
      for (final size in _phoneSizes) {
        await _usePhone(tester, size);
        final dependencies = _dependencies(_routes());
        addTearDown(dependencies.dispose);

        await tester.pumpWidget(
          _app(
            RoutbScopeDependencies(
              dependencies: dependencies,
              child: MyTripScreen(
                request: MyRequest.fromJson(_myRequestJson()),
                onWithdrawn: () {},
              ),
            ),
          ),
        );
        await _settle(tester);

        expect(find.text('Getsemaní → UTB'), findsOneWidget, reason: '$size');
        expect(find.text('Luis Chofer'), findsOneWidget, reason: '$size');
        expect(find.text('3015550002'), findsOneWidget, reason: '$size');
        expect(find.text('Cupo confirmado'), findsOneWidget, reason: '$size');

        // El botón está al final de una lista larga: hay que bajarlo.
        await _scrollToEnd(tester);
        expect(find.text('Cancelar'), findsOneWidget, reason: '$size');
      }
    });

    testWidgets('cancelar pide confirmación y avisa al padre', (tester) async {
      await _usePhone(tester, const Size(360, 640));
      final dependencies = _dependencies(_routes());
      addTearDown(dependencies.dispose);
      var withdrawn = 0;

      await tester.pumpWidget(
        _app(
          RoutbScopeDependencies(
            dependencies: dependencies,
            child: MyTripScreen(
              request: MyRequest.fromJson(_myRequestJson()),
              onWithdrawn: () => withdrawn++,
            ),
          ),
        ),
      );
      await _settle(tester);

      await _scrollToEnd(tester);
      await tester.tap(find.text('Cancelar'));
      await _settle(tester);
      expect(find.text('¿Cancelar este cupo?'), findsOneWidget);

      // Cancelar el diálogo no toca nada.
      await tester.tap(find.text('Mantener cupo'));
      await _settle(tester);
      expect(withdrawn, 0);
      expect(find.text('¿Cancelar este cupo?'), findsNothing);

      await tester.tap(find.text('Cancelar'));
      await _settle(tester);
      await tester.tap(find.text('Cancelar cupo'));
      await _settle(tester);

      expect(withdrawn, 1);

      // El aviso de «Cupo cancelado» se retira solo; hay que dejarlo expirar o
      // queda un temporizador vivo al terminar la prueba.
      await tester.pump(const Duration(seconds: 3));
      await _settle(tester);
    });

    testWidgets('el botón desaparece si el backend no permite retirar', (
      tester,
    ) async {
      await _usePhone(tester, const Size(360, 640));
      final dependencies = _dependencies(_routes());
      addTearDown(dependencies.dispose);

      await tester.pumpWidget(
        _app(
          RoutbScopeDependencies(
            dependencies: dependencies,
            child: MyTripScreen(
              request: MyRequest.fromJson(_myRequestJson())
                  .copyWith(canWithdraw: false),
              onWithdrawn: () {},
            ),
          ),
        ),
      );
      await _settle(tester);

      await _scrollToEnd(tester);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Volver a buscar viajes'), findsNothing);
    });

    testWidgets('avisa si el viaje se canceló', (tester) async {
      await _usePhone(tester, const Size(360, 640));
      final dependencies = _dependencies(_routes());
      addTearDown(dependencies.dispose);

      await tester.pumpWidget(
        _app(
          RoutbScopeDependencies(
            dependencies: dependencies,
            child: MyTripScreen(
              request: MyRequest.fromJson(
                _myRequestJson(tripStatus: 'cancelled'),
              ),
              onWithdrawn: () {},
            ),
          ),
        ),
      );
      await _settle(tester);

      expect(find.text('Viaje cancelado'), findsOneWidget);

      await _scrollToEnd(tester);
      expect(
        find.textContaining('El conductor canceló la ruta'),
        findsOneWidget,
      );
    });
  });

  group('MyRequest', () {
    test('lee el JSON de `/requests/me`', () {
      final request = MyRequest.fromJson(_myRequestJson());

      expect(request.id, 7);
      expect(request.tripId, 1);
      expect(request.isConfirmed, isTrue);
      expect(request.isActive, isTrue);
      expect(request.isOrphaned, isFalse);
      expect(request.routeLabel, 'Getsemaní → UTB');
      expect(request.statusLabel, 'Cupo confirmado');
      expect(request.driverInitials, 'LC');
      expect(request.canWithdraw, isTrue);
    });

    test('un viaje cancelado deja la solicitud sin sentido', () {
      final request = MyRequest.fromJson(
        _myRequestJson(tripStatus: 'cancelled'),
      );

      expect(request.isOrphaned, isTrue);
      expect(request.statusLabel, 'Viaje cancelado');
    });

    test('una solicitud pendiente sigue viva', () {
      final request = MyRequest.fromJson(_myRequestJson(status: 'pending'));

      expect(request.isPending, isTrue);
      expect(request.isActive, isTrue);
      expect(request.statusLabel, 'Solicitud enviada');
    });

    test('una solicitud rechazada no es un viaje en curso', () {
      final request = MyRequest.fromJson(_myRequestJson(status: 'rejected'));

      expect(request.isActive, isFalse);
      expect(request.statusLabel, 'No aceptada');
    });
  });

  group('TripRepository.myRequests', () {
    test('usa `GET /requests/me` cuando el endpoint existe', () async {
      final dependencies = _dependencies(
        _routes(
          trips: const <Map<String, dynamic>>[],
          myRequests: <Map<String, dynamic>>[_myRequestJson()],
        ),
      );
      addTearDown(dependencies.dispose);

      final requests = await dependencies.trips.myRequests();

      expect(requests, hasLength(1));
      expect(requests.single.tripId, 1);
    });

    test('si el endpoint no existe, deriva el viaje de `GET /trips/`', () async {
      // Respaldo para un backend sin redesplegar: el buscador ya dice que hay
      // solicitud, así que la tarjeta puede mostrarse, pero sin id de solicitud
      // no hay retiro.
      final dependencies = _dependencies(
        _routes(
          trips: <Map<String, dynamic>>[_tripJson(myStatus: 'accepted')],
          requestsMeMissing: true,
        ),
      );
      addTearDown(dependencies.dispose);

      final requests = await dependencies.trips.myRequests();

      expect(requests, hasLength(1));
      expect(requests.single.tripId, 1);
      expect(requests.single.isConfirmed, isTrue);
      expect(requests.single.canWithdraw, isFalse);
    });

    test('el respaldo no inventa viajes sin solicitud propia', () async {
      final dependencies = _dependencies(
        _routes(
          trips: <Map<String, dynamic>>[_tripJson()],
          requestsMeMissing: true,
        ),
      );
      addTearDown(dependencies.dispose);

      expect(await dependencies.trips.myRequests(), isEmpty);
    });
  });
}
