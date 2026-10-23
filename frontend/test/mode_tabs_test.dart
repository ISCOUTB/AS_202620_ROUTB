import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/app/dependencies.dart';
import 'package:frontend/core/models/user_role.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/session_store.dart';
import 'package:frontend/core/theme/routb_theme.dart';
import 'package:frontend/core/theme/theme_controller.dart';
import 'package:frontend/core/widgets/routb_hero.dart';
import 'package:frontend/core/widgets/routb_nav_bar.dart';
import 'package:frontend/features/auth/data/auth_repository.dart';
import 'package:frontend/features/driver/screens/driver_screen.dart';
import 'package:frontend/features/matching/data/matching_repository.dart';
import 'package:frontend/features/notifications/data/notifications_repository.dart';
import 'package:frontend/features/notifications/push_notification_service.dart';
import 'package:frontend/features/passenger/screens/passenger_screen.dart';
import 'package:frontend/features/trips/data/trip_repository.dart';

const Map<String, String> _json = <String, String>{
  'content-type': 'application/json',
};

const Account _driver = Account(
  token: 't',
  name: 'Sebastián',
  role: UserRole.driver,
);
const Account _passenger = Account(
  token: 't',
  name: 'Ana',
  role: UserRole.passenger,
);

/// Un viaje en JSON, tal como lo devuelve `GET /trips/` y `my-trips`.
Map<String, dynamic> _tripJson({
  required int id,
  required String origin,
  required String destination,
  String status = 'active',
  String? date,
}) => <String, dynamic>{
  'id': id,
  'origin': origin,
  'destination': destination,
  'total_seats': 4,
  'available_seats': 2,
  'departure_time': '7:00 AM',
  'status': status,
  'departure_date': ?date,
  'driver_id': 2,
  'driver_name': 'Luis Chofer',
};

Map<String, dynamic> _profileJson({
  required String name,
  required String lastName,
  required String phone,
  required String role,
  String? consentAt,
}) => <String, dynamic>{
  'id': 7,
  'name': name,
  'last_name': lastName,
  'phone': phone,
  'role': role,
  'location_consent_at': consentAt,
};

/// Respuestas del modo conductor: una ruta vigente, otra cancelada y una
/// pasada de fecha, más el perfil.
class _DriverApi {
  late final http.Client client = MockClient((request) async {
    final path = request.url.path;
    if (request.method == 'GET' && path == '/trips/my-trips') {
      if (request.url.queryParameters['scope'] == 'history') {
        return http.Response(
          jsonEncode(<Map<String, dynamic>>[
            _tripJson(
              id: 2,
              origin: 'Centro',
              destination: 'UTB',
              status: 'cancelled',
            ),
            _tripJson(
              id: 3,
              origin: 'Bocagrande',
              destination: 'UTB',
              date: '2026-01-01',
            ),
          ]),
          200,
          headers: _json,
        );
      }
      return http.Response(
        jsonEncode(<Map<String, dynamic>>[
          _tripJson(id: 1, origin: 'Manga', destination: 'UTB'),
        ]),
        200,
        headers: _json,
      );
    }
    if (request.method == 'GET' && path == '/requests/trips/1') {
      return http.Response('[]', 200, headers: _json);
    }
    if (request.method == 'GET' && path == '/auth/me') {
      return http.Response(
        jsonEncode(
          _profileJson(
            name: 'Sebastián',
            lastName: 'Ríos',
            phone: '3001234567',
            role: 'driver',
          ),
        ),
        200,
        headers: _json,
      );
    }
    return http.Response('{"detail":"Not Found"}', 404, headers: _json);
  });
}

/// Respuestas del modo pasajero: sin viajes y con el consentimiento vigente.
class _PassengerApi {
  late final http.Client client = MockClient((request) async {
    final path = request.url.path;
    if (request.method == 'GET' &&
        (path == '/trips/' || path == '/requests/me')) {
      return http.Response('[]', 200, headers: _json);
    }
    if (request.method == 'GET' && path == '/auth/me') {
      return http.Response(
        jsonEncode(
          _profileJson(
            name: 'Ana',
            lastName: 'García',
            phone: '3007654321',
            role: 'passenger',
            consentAt: DateTime(2026, 10, 9, 12).toIso8601String(),
          ),
        ),
        200,
        headers: _json,
      );
    }
    return http.Response('{"detail":"Not Found"}', 404, headers: _json);
  });
}

RoutbDependencies _dependencies(http.Client client) {
  final session = SessionStore();
  final api = ApiClient(session, client: client);
  return RoutbDependencies(
    session: session,
    auth: AuthRepository(api, session),
    trips: TripRepository(api),
    matching: MatchingRepository(api),
    push: PushNotificationService(repository: NotificationsRepository(api)),
    theme: ThemeController(session),
  );
}

/// Monta la pantalla con las dos piezas que necesita: el tema y las
/// dependencias.
Widget _app(RoutbDependencies dependencies, Widget home) => MaterialApp(
  theme: RoutbTheme.light(),
  home: RoutbScope(
    controller: dependencies.theme,
    child: RoutbScopeDependencies(dependencies: dependencies, child: home),
  ),
);

/// Pestaña de la barra inferior, para no confundirla con los títulos que
/// repiten el mismo texto dentro de cada pantalla.
Finder _tab(String label) =>
    find.descendant(of: find.byType(RoutbNavBar), matching: find.text(label));

/// Fija el tamaño de pantalla y lo restablece al terminar.
void _usePhone(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

/// Deja correr los cuadros que necesitan las peticiones y las animaciones.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

/// Baja hasta el final de la lista del perfil para alcanzar el botón de salir.
Future<void> _scrollToLogout(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, -400));
  await _settle(tester);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('Modo conductor', () {
    testWidgets('el historial vive en su propia pestaña', (tester) async {
      _usePhone(tester, const Size(390, 844));
      final dependencies = _dependencies(_DriverApi().client);
      addTearDown(dependencies.dispose);

      await tester.pumpWidget(
        _app(dependencies, DriverScreen(account: _driver)),
      );
      await _settle(tester);

      // En «Mis rutas» solo está la vigente; tampoco se asoma el historial.
      expect(find.text('Manga → UTB'), findsWidgets);
      expect(find.text('Centro → UTB'), findsNothing);
      expect(find.text('Bocagrande → UTB'), findsNothing);
      expect(find.text('Nueva ruta'), findsOneWidget);

      // La barra superior ya no trae el modo de pantalla ni la ubicación:
      // ambos viven en la pestaña de perfil.
      expect(find.byType(ThemeToggle), findsNothing);
      expect(find.byTooltip('Privacidad de ubicación'), findsNothing);

      await tester.tap(_tab('Historial'));
      await _settle(tester);

      // La cancelada y la pasada viven aquí, y la vigente ya no se ve.
      expect(find.text('Centro → UTB'), findsOneWidget);
      expect(find.text('Bocagrande → UTB'), findsOneWidget);
      expect(find.text('Manga → UTB'), findsNothing);
      expect(find.text('Nueva ruta'), findsNothing);
    });

    testWidgets('la pestaña de perfil reúne datos, modo y ubicación', (
      tester,
    ) async {
      _usePhone(tester, const Size(390, 844));
      final dependencies = _dependencies(_DriverApi().client);
      addTearDown(dependencies.dispose);

      await tester.pumpWidget(
        _app(dependencies, DriverScreen(account: _driver)),
      );
      await _settle(tester);

      await tester.tap(_tab('Perfil'));
      await _settle(tester);

      expect(find.text('Sebastián Ríos'), findsOneWidget);
      expect(find.text('3001234567'), findsOneWidget);
      expect(find.text('Modo de pantalla'), findsOneWidget);
      // Sin consentimiento, el perfil ofrece autorizar.
      expect(find.text('Autorizar ubicación'), findsOneWidget);

      await _scrollToLogout(tester);
      expect(find.text('Cerrar sesión'), findsOneWidget);
    });

    testWidgets('las tres pestañas caben en un móvil estrecho', (tester) async {
      for (final size in const <Size>[
        Size(320, 568),
        Size(360, 640),
        Size(390, 844),
      ]) {
        _usePhone(tester, size);
        final dependencies = _dependencies(_DriverApi().client);
        addTearDown(dependencies.dispose);

        await tester.pumpWidget(
          _app(dependencies, DriverScreen(account: _driver)),
        );
        await _settle(tester);

        expect(find.byType(RoutbNavBar), findsOneWidget, reason: '$size');
        await tester.tap(_tab('Historial'));
        await _settle(tester);
        await tester.tap(_tab('Perfil'));
        await _settle(tester);
        await tester.tap(_tab('Mis rutas'));
        await _settle(tester);
      }
    });
  });

  group('Modo pasajero', () {
    testWidgets('el perfil también es una pestaña del pasajero', (
      tester,
    ) async {
      _usePhone(tester, const Size(390, 844));
      final dependencies = _dependencies(_PassengerApi().client);
      addTearDown(dependencies.dispose);

      await tester.pumpWidget(
        _app(dependencies, PassengerScreen(account: _passenger)),
      );
      await _settle(tester);

      await tester.tap(_tab('Perfil'));
      await _settle(tester);

      expect(find.text('Ana García'), findsOneWidget);
      expect(find.text('Pasajero'), findsOneWidget);
      expect(find.text('Modo de pantalla'), findsOneWidget);
      expect(find.text('Autorizado'), findsOneWidget);

      await _scrollToLogout(tester);
      expect(find.text('Cerrar sesión'), findsOneWidget);
    });
  });
}
