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
Map<String, dynamic> _profileJson({
  String? consentAt,
  String role = 'driver',
  String? vehicleModel,
  String? vehiclePlate,
  String? vehicleColor,
}) => <String, dynamic>{
  'id': 7,
  'name': 'Sebastián',
  'last_name': 'Ríos',
  'phone': '3001234567',
  'role': role,
  'location_consent_at': consentAt,
  'vehicle_model': vehicleModel,
  'vehicle_plate': vehiclePlate,
  'vehicle_color': vehicleColor,
};

/// Servidor de mentira con el perfil en memoria: la autorización de ubicación
/// cambia con el `POST` y el `DELETE` igual que en el backend, y el vehículo
/// con el `PATCH`.
class _FakeApi {
  _FakeApi(this.profile, {this.meStatus = 200});

  Map<String, dynamic> profile;
  final int meStatus;
  int vehicleCalls = 0;
  Map<String, dynamic>? lastVehicleBody;

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
    if (request.method == 'PATCH' && path == '/users/me/vehicle') {
      vehicleCalls++;
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      lastVehicleBody = body;
      profile = <String, dynamic>{...profile, ...body};
      return http.Response(jsonEncode(profile), 200, headers: _json);
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

/// Baja hasta la tarjeta del vehículo del conductor.
Future<void> _scrollToVehicle(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, -300));
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

    testWidgets('el conductor registra su vehículo desde el perfil', (
      tester,
    ) async {
      final api = _FakeApi(_profileJson());
      final dependencies = _dependencies(api);
      addTearDown(dependencies.dispose);

      await tester.pumpWidget(
        _app(dependencies, Scaffold(body: ProfileScreen(account: _driver))),
      );
      await _settle(tester);
      await _scrollToVehicle(tester);

      expect(find.text('Vehículo'), findsOneWidget);
      expect(find.text('Sin registrar'), findsOneWidget);

      await tester.tap(find.text('Registrar vehículo'));
      await _settle(tester);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Chevrolet Spark');
      await tester.enterText(fields.at(1), 'xyz 123');
      await tester.enterText(fields.at(2), 'Gris');
      await tester.pump();

      await tester.tap(find.text('Guardar vehículo'));
      await _settle(tester);

      expect(api.vehicleCalls, 1);
      expect(api.lastVehicleBody?['vehicle_plate'], 'XYZ-123');
      expect(find.text('Chevrolet Spark · Gris (XYZ-123)'), findsOneWidget);
      expect(find.text('Registrado'), findsOneWidget);
      await _drainToast(tester);
    });

    testWidgets('una placa inválida no llega al backend', (tester) async {
      final api = _FakeApi(_profileJson());
      final dependencies = _dependencies(api);
      addTearDown(dependencies.dispose);

      await tester.pumpWidget(
        _app(dependencies, Scaffold(body: ProfileScreen(account: _driver))),
      );
      await _settle(tester);
      await _scrollToVehicle(tester);

      await tester.tap(find.text('Registrar vehículo'));
      await _settle(tester);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Chevrolet Spark');
      await tester.enterText(fields.at(1), '123');
      await tester.enterText(fields.at(2), 'Gris');
      await tester.pump();

      await tester.tap(find.text('Guardar vehículo'));
      await _settle(tester);

      expect(api.vehicleCalls, 0);
      expect(find.textContaining('placa colombiana válida'), findsOneWidget);

      // Cerrar la hoja para que no quede abierta al terminar la prueba.
      await tester.tap(find.bySemanticsLabel('Cerrar'));
      await _settle(tester);
    });

    testWidgets('editar el vehículo permite quitarlo con confirmación', (
      tester,
    ) async {
      final api = _FakeApi(
        _profileJson(
          vehicleModel: 'Chevrolet Spark',
          vehiclePlate: 'XYZ-123',
          vehicleColor: 'Gris',
        ),
      );
      final dependencies = _dependencies(api);
      addTearDown(dependencies.dispose);

      await tester.pumpWidget(
        _app(dependencies, Scaffold(body: ProfileScreen(account: _driver))),
      );
      await _settle(tester);
      await _scrollToVehicle(tester);

      expect(find.text('Chevrolet Spark · Gris (XYZ-123)'), findsOneWidget);

      await tester.tap(find.text('Editar vehículo'));
      await _settle(tester);
      await tester.drag(
        find.byType(SingleChildScrollView).last,
        const Offset(0, -160),
      );
      await _settle(tester);
      await tester.tap(find.text('Quitar vehículo'));
      await _settle(tester);
      expect(find.text('¿Quitar el vehículo?'), findsOneWidget);

      await tester.tap(find.text('Quitar'));
      await _settle(tester);

      expect(api.vehicleCalls, 1);
      expect(api.lastVehicleBody?['vehicle_plate'], isNull);
      expect(find.text('Sin registrar'), findsOneWidget);
      expect(find.text('Registrar vehículo'), findsOneWidget);
      await _drainToast(tester);
    });

    testWidgets('el pasajero no ve la tarjeta del vehículo', (tester) async {
      final dependencies = _dependencies(
        _FakeApi(_profileJson(role: 'passenger')),
      );
      addTearDown(dependencies.dispose);

      await tester.pumpWidget(
        _app(
          dependencies,
          Scaffold(
            body: ProfileScreen(
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
      await _scrollToVehicle(tester);

      expect(find.text('Vehículo'), findsNothing);
      expect(find.text('Registrar vehículo'), findsNothing);
    });
  });
}
