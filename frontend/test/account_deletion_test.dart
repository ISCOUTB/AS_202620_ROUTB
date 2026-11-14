import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/core/models/user_role.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/network/api_exception.dart';
import 'package:frontend/core/storage/session_store.dart';
import 'package:frontend/features/auth/data/auth_repository.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('deleteAccount borra la cuenta y limpia la sesión local', () async {
    final session = SessionStore();
    await session.save(
      token: 'token-prueba',
      name: 'Sebastián',
      role: UserRole.passenger,
    );

    String? method;
    String? path;
    String? authorization;
    final client = MockClient((request) async {
      method = request.method;
      path = request.url.path;
      authorization = request.headers['Authorization'];
      return http.Response('', 204);
    });
    final repository = AuthRepository(
      ApiClient(session, client: client),
      session,
    );

    await repository.deleteAccount();

    expect(method, 'DELETE');
    expect(path, '/users/me');
    expect(authorization, 'Bearer token-prueba');
    expect(await session.readToken(), isNull);
    expect(await session.readName(), isNull);
    expect(await session.readRole(), isNull);
  });

  test(
    'si hay compromisos activos el backend responde 409 y no se limpia',
    () async {
      final session = SessionStore();
      await session.save(
        token: 'token-prueba',
        name: 'Sebastián',
        role: UserRole.passenger,
      );

      final client = MockClient(
        (_) async => http.Response(
          jsonEncode(<String, String>{
            'detail':
                'Cancela tus rutas activas y solicitudes pendientes antes de '
                'eliminar tu cuenta.',
          }),
          409,
          headers: <String, String>{'content-type': 'application/json'},
        ),
      );
      final repository = AuthRepository(
        ApiClient(session, client: client),
        session,
      );

      await expectLater(
        repository.deleteAccount(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            contains('Cancela tus rutas activas'),
          ),
        ),
      );
      expect(await session.readToken(), 'token-prueba');
    },
  );
}
