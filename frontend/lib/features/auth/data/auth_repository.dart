import '../../../core/models/user_profile.dart';
import '../../../core/models/user_role.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/session_store.dart';

/// Persona que está usando la app tras entrar.
class Account {
  const Account({required this.name, required this.role, required this.token});

  /// Nombre con el que se saluda en el hero.
  final String name;

  /// Perfil con el que entró.
  final UserRole role;

  /// Token JWT con el que se autentican las peticiones.
  final String token;
}

/// Ingreso, registro y cierre de sesión.
class AuthRepository {
  AuthRepository(this._api, this._session);

  final ApiClient _api;
  final SessionStore _session;

  /// `POST /users/` seguido de `POST /auth/login`.
  ///
  /// El registro no devuelve token, así que para no obligar a la persona a
  /// escribir su contraseña otra vez, esta llamada inicia sesión con las
  /// mismas credenciales justo después de crearse la cuenta.
  Future<Account> register({
    required String name,
    required String lastName,
    required String phone,
    required String password,
    required UserRole role,
  }) async {
    await _api.post(
      '/users/',
      authenticated: false,
      body: <String, Object?>{
        'name': name.trim(),
        'last_name': lastName.trim(),
        'phone': phone.trim(),
        'password': password,
        'role': role.wire,
      },
    );

    return login(phone: phone, password: password);
  }

  /// `POST /auth/login`
  Future<Account> login({
    required String phone,
    required String password,
  }) async {
    final response = await _api.post(
      '/auth/login',
      authenticated: false,
      body: <String, Object?>{'phone': phone.trim(), 'password': password},
    );

    final account = _accountOf(response);

    await _session.save(
      token: account.token,
      name: account.name,
      role: account.role,
    );
    return account;
  }

  /// Cierra sesión en el backend si se puede y borra la sesión local.
  ///
  /// `GET /auth/me` es la única forma de confirmar el token. Si la red falla se
  /// borra igual: la sesión local es lo que decide si la persona entra.
  Future<void> logout() async {
    try {
      await _api.get('/auth/me');
    } on ApiException {
      // Sin token válido o sin red: se limpia la sesión local de todos modos.
    }

    await _session.clear();
  }

  /// Registra en el backend el consentimiento para usar geocodificación.
  Future<void> grantLocationConsent() async {
    await _api.post('/users/me/location-consent');
  }

  /// `GET /auth/me`
  ///
  /// Perfil de solo lectura para la pantalla de Perfil: nombre completo,
  /// teléfono, rol y estado del consentimiento de ubicación. Es la misma
  /// información que devuelve el ingreso, pero siempre fresca.
  Future<UserProfile> fetchProfile() async {
    final response = await _api.get('/auth/me');
    if (response is! Map<String, dynamic>) {
      throw const ApiException('El servidor no devolvió el perfil.');
    }
    return UserProfile.fromJson(response);
  }

  /// Revoca el consentimiento y hace que el backend elimine las paradas de
  /// solicitudes pendientes.
  Future<void> revokeLocationConsent() async {
    await _api.delete('/users/me/location-consent');
  }

  /// Devuelve la cuenta guardada en el dispositivo si sigue siendo válida en
  /// el backend, o `null` si no hay o si el token ya expiró.
  Future<Account?> restore() async {
    final token = await _session.readToken();
    final name = await _session.readName();
    final role = await _session.readRole();
    if (token == null || name == null || role == null) return null;

    try {
      final user = await _api.get('/auth/me');
      if (user is Map<String, dynamic>) {
        final serverName = (user['name'] as String?)?.trim();
        final serverRole = UserRole.fromWire(user['role'] as String?);
        return Account(
          name: serverName != null && serverName.isNotEmpty ? serverName : name,
          role: serverRole,
          token: token,
        );
      }
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        // El token expiró o ya no es válido en el servidor: limpiamos sesión.
        await _session.clear();
        return null;
      }
      // Si fue error de red temporal (sin conexión), permitimos pasar con la sesión en caché.
    } catch (_) {
      // Si fue error de red u otro, permitimos restaurar la sesión local.
    }

    return Account(name: name, role: role, token: token);
  }

  Account _accountOf(Object? response) {
    if (response is! Map<String, dynamic>) {
      throw const ApiException('El servidor no devolvió una sesión válida.');
    }
    final token = response['access_token'];
    final user = response['user'];
    if (token is! String || token.isEmpty || user is! Map<String, dynamic>) {
      throw const ApiException('El servidor no devolvió una sesión válida.');
    }
    final name = (user['name'] as String?)?.trim();
    if (name == null || name.isEmpty) {
      throw const ApiException('El servidor no devolvió un nombre de usuario.');
    }
    return Account(
      name: name,
      role: UserRole.fromWire(user['role'] as String?),
      token: token,
    );
  }
}
