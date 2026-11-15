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
import 'package:frontend/features/driver/screens/driver_screen.dart';
import 'package:frontend/features/matching/data/matching_repository.dart';
import 'package:frontend/features/notifications/data/notifications_repository.dart';
import 'package:frontend/features/notifications/push_notification_service.dart';
import 'package:frontend/features/trips/data/trip_repository.dart';

const Map<String, String> _json = <String, String>{
  'content-type': 'application/json',
};

const Account _driver = Account(
  token: 't',
  name: 'Sebastián',
  role: UserRole.driver,
);

/// Servidor de mentira: no hay rutas y el perfil puede tener o no vehículo.
class _FakeApi {
  _FakeApi({this.vehicleComplete = false});

  final bool vehicleComplete;

  late final http.Client client = MockClient((request) async {
    final path = request.url.path;
    if (request.method == 'GET' && path == '/trips/my-trips') {
      return http.Response('[]', 200, headers: _json);
    }
    if (request.method == 'GET' && path == '/auth/me') {
      return http.Response(
        jsonEncode(<String, dynamic>{
          'id': 7,
          'name': 'Sebastián',
          'last_name': 'Ríos',
          'phone': '3001234567',
          'role': 'driver',
          'vehicle_model': vehicleComplete ? 'Chevrolet Spark' : null,
          'vehicle_plate': vehicleComplete ? 'XYZ-123' : null,
          'vehicle_color': vehicleComplete ? 'Gris' : null,
        }),
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

Widget _app(RoutbDependencies dependencies) => MaterialApp(
  theme: RoutbTheme.light(),
  home: RoutbScope(
    controller: dependencies.theme,
    child: RoutbScopeDependencies(
      dependencies: dependencies,
      child: const DriverScreen(account: _driver),
    ),
  ),
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('sin vehículo avisa y lleva a Perfil antes de publicar', (
    tester,
  ) async {
    final dependencies = _dependencies(_FakeApi().client);
    addTearDown(dependencies.dispose);

    await tester.pumpWidget(_app(dependencies));
    await _settle(tester);

    await tester.tap(find.text('Nueva ruta'));
    await _settle(tester);

    expect(find.text('Configura tu vehículo'), findsOneWidget);
    expect(find.textContaining('Falta completar'), findsOneWidget);
    expect(find.text('Trayecto y horario'), findsNothing);

    await tester.tap(find.text('Ir a Perfil'));
    await _settle(tester);

    expect(find.text('Modo de pantalla'), findsOneWidget);
  });

  testWidgets('con vehículo completo abre el formulario de publicación', (
    tester,
  ) async {
    final dependencies = _dependencies(_FakeApi(vehicleComplete: true).client);
    addTearDown(dependencies.dispose);

    await tester.pumpWidget(_app(dependencies));
    await _settle(tester);

    await tester.tap(find.text('Nueva ruta'));
    await _settle(tester);

    expect(find.text('Configura tu vehículo'), findsNothing);
    expect(find.text('Trayecto y horario'), findsOneWidget);
  });
}
