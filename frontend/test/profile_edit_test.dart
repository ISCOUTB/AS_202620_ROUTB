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

const Account _account = Account(
  token: 't',
  name: 'Sebastián',
  role: UserRole.driver,
);

/// Servidor de mentira para el perfil: guarda los cuerpos que reciben los
/// endpoints de edición y puede forzar el fallo de la contraseña actual.
class _FakeApi {
  _FakeApi({this.wrongPassword = false});

  final bool wrongPassword;
  Map<String, dynamic> profile = <String, dynamic>{
    'id': 7,
    'name': 'Sebastián',
    'last_name': 'Ríos',
    'phone': '3001234567',
    'role': 'driver',
    'vehicle_model': 'Chevrolet Spark',
    'vehicle_plate': 'XYZ-123',
    'vehicle_color': 'Gris',
  };

  int profileCalls = 0;
  int passwordCalls = 0;
  Map<String, dynamic>? lastProfileBody;
  Map<String, dynamic>? lastPasswordBody;

  late final http.Client client = MockClient((request) async {
    final path = request.url.path;
    if (request.method == 'GET' && path == '/auth/me') {
      return http.Response(jsonEncode(profile), 200, headers: _json);
    }
    if (request.method == 'PATCH' && path == '/users/me') {
      profileCalls++;
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      lastProfileBody = body;
      profile = <String, dynamic>{...profile, ...body};
      return http.Response(jsonEncode(profile), 200, headers: _json);
    }
    if (request.method == 'PATCH' && path == '/users/me/password') {
      passwordCalls++;
      lastPasswordBody = jsonDecode(request.body) as Map<String, dynamic>;
      if (wrongPassword) {
        return http.Response(
          '{"detail":"La contraseña actual no es correcta"}',
          400,
          headers: _json,
        );
      }
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
    trips: TripRepository(client),
    matching: MatchingRepository(client),
    push: PushNotificationService(repository: NotificationsRepository(client)),
    theme: ThemeController(session),
  );
}

Widget _app(RoutbDependencies dependencies) => MaterialApp(
  theme: RoutbTheme.light(),
  home: RoutbScope(
    controller: dependencies.theme,
    child: RoutbScopeDependencies(
      dependencies: dependencies,
      child: Scaffold(body: ProfileScreen(account: _account)),
    ),
  ),
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

/// Deja que el aviso de [RoutbToast] termine antes de cerrar la prueba.
Future<void> _drainToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await _settle(tester);
}

Future<void> _openEditAccount(WidgetTester tester) async {
  await tester.tap(find.text('Editar cuenta'));
  await _settle(tester);
}

Future<void> _openPersonalData(WidgetTester tester) async {
  await _openEditAccount(tester);
  await tester.tap(find.text('Editar datos personales'));
  await _settle(tester);
}

Future<void> _openPasswordSheet(WidgetTester tester) async {
  await _openEditAccount(tester);
  await tester.tap(find.text('Cambiar contraseña'));
  await _settle(tester);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('edita nombre, apellido y teléfono desde Editar cuenta', (
    tester,
  ) async {
    final api = _FakeApi();
    final dependencies = _dependencies(api);
    addTearDown(dependencies.dispose);

    await tester.pumpWidget(_app(dependencies));
    await _settle(tester);
    await _openPersonalData(tester);

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(3));
    await tester.enterText(fields.at(0), 'Carolina');
    await tester.enterText(fields.at(1), 'Méndez');
    await tester.enterText(fields.at(2), '300 555 0101');
    await tester.pump();

    await tester.tap(find.text('Guardar cambios'));
    await _settle(tester);

    expect(api.profileCalls, 1);
    expect(api.lastProfileBody?['name'], 'Carolina');
    expect(api.lastProfileBody?['last_name'], 'Méndez');
    expect(api.lastProfileBody?['phone'], '3005550101');
    expect(find.text('Carolina Méndez'), findsOneWidget);
    expect(find.text('3005550101'), findsOneWidget);
    expect(await dependencies.session.readName(), 'Carolina');
    await _drainToast(tester);
  });

  testWidgets('un teléfono inválido no llega al backend', (tester) async {
    final api = _FakeApi();
    final dependencies = _dependencies(api);
    addTearDown(dependencies.dispose);

    await tester.pumpWidget(_app(dependencies));
    await _settle(tester);
    await _openPersonalData(tester);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(2), '123');
    await tester.pump();
    await tester.tap(find.text('Guardar cambios'));
    await _settle(tester);

    expect(api.profileCalls, 0);
    expect(
      find.text('Ingresa un celular colombiano de 10 dígitos'),
      findsOneWidget,
    );

    await tester.tap(find.bySemanticsLabel('Cerrar'));
    await _settle(tester);
  });

  testWidgets('cambia la contraseña con la actual', (tester) async {
    final api = _FakeApi();
    final dependencies = _dependencies(api);
    addTearDown(dependencies.dispose);

    await tester.pumpWidget(_app(dependencies));
    await _settle(tester);
    await _openPasswordSheet(tester);

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(3));
    await tester.enterText(fields.at(0), 'PasswordSegura123!');
    await tester.enterText(fields.at(1), 'NuevaPassword456!');
    await tester.enterText(fields.at(2), 'NuevaPassword456!');
    await tester.pump();

    await tester.tap(find.text('Guardar contraseña'));
    await _settle(tester);

    expect(api.passwordCalls, 1);
    expect(api.lastPasswordBody?['current_password'], 'PasswordSegura123!');
    expect(api.lastPasswordBody?['new_password'], 'NuevaPassword456!');
    expect(find.text('Contraseña actualizada'), findsOneWidget);
    await _drainToast(tester);
  });

  testWidgets('una contraseña actual incorrecta se muestra en el campo', (
    tester,
  ) async {
    final api = _FakeApi(wrongPassword: true);
    final dependencies = _dependencies(api);
    addTearDown(dependencies.dispose);

    await tester.pumpWidget(_app(dependencies));
    await _settle(tester);
    await _openPasswordSheet(tester);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Incorrecta123!');
    await tester.enterText(fields.at(1), 'NuevaPassword456!');
    await tester.enterText(fields.at(2), 'NuevaPassword456!');
    await tester.pump();

    await tester.tap(find.text('Guardar contraseña'));
    await _settle(tester);

    expect(api.passwordCalls, 1);
    expect(find.text('La contraseña actual no es correcta'), findsOneWidget);
  });

  testWidgets('la confirmación distinta no envía el cambio', (tester) async {
    final api = _FakeApi();
    final dependencies = _dependencies(api);
    addTearDown(dependencies.dispose);

    await tester.pumpWidget(_app(dependencies));
    await _settle(tester);
    await _openPasswordSheet(tester);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'PasswordSegura123!');
    await tester.enterText(fields.at(1), 'NuevaPassword456!');
    await tester.enterText(fields.at(2), 'OtraPassword789!');
    await tester.pump();

    await tester.tap(find.text('Guardar contraseña'));
    await _settle(tester);

    expect(api.passwordCalls, 0);
    expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
  });
}
