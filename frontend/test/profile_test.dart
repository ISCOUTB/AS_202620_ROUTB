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
import 'package:frontend/features/auth/data/auth_repository.dart';
import 'package:frontend/features/matching/data/matching_repository.dart';
import 'package:frontend/features/notifications/data/notifications_repository.dart';
import 'package:frontend/features/notifications/push_notification_service.dart';
import 'package:frontend/features/profile/screens/profile_screen.dart';
import 'package:frontend/features/trips/data/geocode_repository.dart';
import 'package:frontend/features/trips/data/trip_repository.dart';

const Map<String, String> _json = <String, String>{
  'content-type': 'application/json',
};

const Account _driver = Account(
  token: 't',
  name: 'Sebastián',
  role: UserRole.driver,
);

/// Perfil tal como lo devuelve `GET /auth/me`.
Map<String, dynamic> _profileJson({String? consentAt}) => <String, dynamic>{
  'id': 7,
  'name': 'Sebastián',
  'last_name': 'Ríos',
  'phone': '3001234567',
  'role': 'driver',
  'location_consent_at': consentAt,
};

/// Servidor de mentira con el perfil en memoria: la autorización de ubicación
/// cambia con el `POST` y el `DELETE` igual que en el backend.
class _FakeApi {
  _FakeApi(this.profile, {this.meStatus = 200});

  Map<String, dynamic> profile;
  final int meStatus;

  late final http.Client client = MockClient((request) async {
    final path = request.url.path;
    if (request.method == 'GET' && path == '/auth/me') {
      return http.Response(jsonEncode(profile), meStatus, headers: _json);
    }
    if (request.method == 'POST' && path == '/users/me/location-consent') {
      profile = <String, dynamic>{
        ...profile,
        'location_consent_at': DateTime(2026, 10, 16, 9).toIso8601String(),
      };
      return http.Response('', 204);
    }
    if (request.method == 'DELETE' && path == '/users/me/location-consent') {
      profile = <String, dynamic>{...profile, 'location_consent_at': null};
      return http.Response('', 204);
    }
    return http.Response('{"detail":"Not Found"}', 404, headers: _json);
  });
}

RoutbDependencies _dependencies(_FakeApi api) {
  final session = SessionStore();
  final client = ApiClient(session, client: api.client);
  return RoutbDependencies(
    session: session,
    auth: AuthRepository(client, session),
    geocode: GeocodeRepository(client),
    trips: TripRepository(client),
    matching: MatchingRepository(client),
    push: PushNotificationService(repository: NotificationsRepository(client)),
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

/// Deja correr los cuadros que necesitan las peticiones y las animaciones.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

/// Deja que el aviso de [RoutbToast] termine de mostrarse y retirarse.
Future<void> _drainToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await _settle(tester);
}

/// Baja hasta el final de la lista del perfil para alcanzar el botón de salir.
Future<void> _scrollToLogout(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, -400));
  await _settle(tester);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('Pestaña de perfil', () {
    testWidgets('muestra datos, modo de pantalla y ubicación', (tester) async {
      final api = _FakeApi(
        _profileJson(consentAt: DateTime(2026, 10, 9, 12).toIso8601String()),
      );
      final dependencies = _dependencies(api);
      addTearDown(dependencies.dispose);

      await tester.pumpWidget(
        _app(dependencies, Scaffold(body: ProfileScreen(account: _driver))),
      );
      await _settle(tester);

      expect(find.text('Sebastián Ríos'), findsOneWidget);
      expect(find.text('3001234567'), findsOneWidget);
      expect(find.text('Conductor'), findsOneWidget);
      expect(find.text('Modo de pantalla'), findsOneWidget);
      expect(find.text('Claro'), findsOneWidget);
      expect(find.text('Oscuro'), findsOneWidget);
      expect(find.text('Sistema'), findsOneWidget);
      expect(find.text('Autorizado'), findsOneWidget);
      expect(find.text('Revocar autorización'), findsOneWidget);

      await _scrollToLogout(tester);
      expect(find.text('Cerrar sesión'), findsOneWidget);
    });

    testWidgets('sin consentimiento ofrece autorizar la ubicación', (
      tester,
    ) async {
      final dependencies = _dependencies(_FakeApi(_profileJson()));
      addTearDown(dependencies.dispose);

      await tester.pumpWidget(
        _app(dependencies, Scaffold(body: ProfileScreen(account: _driver))),
      );
      await _settle(tester);

      expect(find.text('Sin autorizar'), findsOneWidget);
      expect(find.text('Autorizar ubicación'), findsOneWidget);
      expect(find.text('Revocar autorización'), findsNothing);
    });

    testWidgets('elegir Oscuro cambia el modo de pantalla', (tester) async {
      final dependencies = _dependencies(_FakeApi(_profileJson()));
      addTearDown(dependencies.dispose);

      await tester.pumpWidget(
        _app(dependencies, Scaffold(body: ProfileScreen(account: _driver))),
      );
      await _settle(tester);
      expect(dependencies.theme.mode, ThemeMode.system);

      await tester.tap(find.text('Oscuro'));
      await tester.pump();

      expect(dependencies.theme.mode, ThemeMode.dark);
    });

    testWidgets('revocar pide confirmación y luego quita la autorización', (
      tester,
    ) async {
      final api = _FakeApi(
        _profileJson(consentAt: DateTime(2026, 10, 9, 12).toIso8601String()),
      );
      final dependencies = _dependencies(api);
      addTearDown(dependencies.dispose);

      await tester.pumpWidget(
        _app(dependencies, Scaffold(body: ProfileScreen(account: _driver))),
      );
      await _settle(tester);

      await tester.tap(find.text('Revocar autorización'));
      await _settle(tester);
      expect(find.text('¿Revocar la ubicación?'), findsOneWidget);

      await tester.tap(find.text('Mantener'));
      await _settle(tester);
      expect(api.profile['location_consent_at'], isNotNull);
      expect(find.text('Revocar autorización'), findsOneWidget);

      await tester.tap(find.text('Revocar autorización'));
      await _settle(tester);
      await tester.tap(find.text('Revocar'));
      await _settle(tester);

      expect(api.profile['location_consent_at'], isNull);
      expect(find.text('Sin autorizar'), findsOneWidget);
      expect(find.text('Revocar autorización'), findsNothing);
      expect(find.text('Autorizar ubicación'), findsOneWidget);
      await _drainToast(tester);
    });

    testWidgets('autorizar la ubicación la registra en el servidor', (
      tester,
    ) async {
      final api = _FakeApi(_profileJson());
      final dependencies = _dependencies(api);
      addTearDown(dependencies.dispose);

      await tester.pumpWidget(
        _app(dependencies, Scaffold(body: ProfileScreen(account: _driver))),
      );
      await _settle(tester);

      await tester.tap(find.text('Autorizar ubicación'));
      await _settle(tester);

      expect(api.profile['location_consent_at'], isNotNull);
      expect(find.text('Autorizado'), findsOneWidget);
      expect(find.text('Autorizar ubicación'), findsNothing);
      expect(find.text('Revocar autorización'), findsOneWidget);
      await _drainToast(tester);
    });

    testWidgets('un fallo del servidor ofrece reintentar', (tester) async {
      final dependencies = _dependencies(
        _FakeApi(_profileJson(), meStatus: 500),
      );
      addTearDown(dependencies.dispose);

      await tester.pumpWidget(
        _app(dependencies, Scaffold(body: ProfileScreen(account: _driver))),
      );
      await _settle(tester);

      expect(find.text('Reintentar'), findsOneWidget);
    });
  });
}
