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
import 'package:frontend/core/widgets/routb_nav_bar.dart';
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

/// Historial con una ruta cancelada y otra pasada de fecha; sin rutas
/// vigentes para que la pestaña se abra sin ruido.
class _HistoryApi {
  late final http.Client client = MockClient((request) async {
    final path = request.url.path;
    if (request.method == 'GET' && path == '/trips/my-trips') {
      if (request.url.queryParameters['scope'] == 'all') {
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
      return http.Response('[]', 200, headers: _json);
    }
    if (request.method == 'GET' && path.startsWith('/requests/trips/')) {
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

Widget _app(RoutbDependencies dependencies, Widget home) => RoutbScope(
  controller: dependencies.theme,
  child: RoutbScopeDependencies(
    dependencies: dependencies,
    child: MaterialApp(theme: RoutbTheme.light(), home: home),
  ),
);

Finder _tab(String label) =>
    find.descendant(of: find.byType(RoutbNavBar), matching: find.text(label));

/// Deja correr los cuadros que necesitan las peticiones y las animaciones.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('el historial del conductor abre el detalle en solo lectura', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final dependencies = _dependencies(_HistoryApi().client);
    addTearDown(dependencies.dispose);

    await tester.pumpWidget(_app(dependencies, DriverScreen(account: _driver)));
    await _settle(tester);

    await tester.tap(_tab('Historial'));
    await _settle(tester);

    expect(find.text('Completadas'), findsOneWidget);
    expect(find.text('Canceladas'), findsOneWidget);
    expect(find.text('Centro → UTB'), findsOneWidget);

    await tester.tap(find.text('Centro → UTB'));
    await _settle(tester);

    expect(find.text('Detalle de la ruta'), findsOneWidget);
    expect(find.textContaining('Encuentro:'), findsNothing);
    expect(find.text('Centro → UTB'), findsOneWidget);
    expect(find.text('Cancelar ruta'), findsNothing);
    expect(find.text('Solicitudes pendientes'), findsNothing);

    await tester.pageBack();
    await _settle(tester);

    expect(find.text('Historial'), findsWidgets);
    expect(find.text('Centro → UTB'), findsOneWidget);
  });
}
