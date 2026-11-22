import '../../../core/models/user_profile.dart';
import '../../../core/models/user_role.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/session_store.dart';

/// Persona que está usando la app tras entrar.
class Account {
  const Account({
    required this.name,
    required this.role,
    required this.token,
    this.id,
    this.profile,
    bool? driverEnabled,
  }) : driverEnabled = driverEnabled ?? (role == UserRole.driver);

  final bool driverEnabled;
  final UserProfile? profile;

  factory Account.fromProfile(UserProfile profile, String token) => Account(
    profile: profile,
    id: profile.id == 0 ? null : profile.id,
    name: profile.name,
    token: token,
    role: profile.role,
    driverEnabled: profile.driverEnabled,
  );

  Account withMode(UserRole mode) => Account(
    id: id,
    profile: profile,
    name: name,
    token: token,
    role: mode,
    driverEnabled: driverEnabled,
  );

  Account copyWith({
    int? id,
    String? name,
    UserRole? role,
    String? token,
    UserProfile? profile,
    bool? driverEnabled,
  }) => Account(
    id: id ?? this.id,
    name: name ?? this.name,
    role: role ?? this.role,
    token: token ?? this.token,
    profile: profile ?? this.profile,
    driverEnabled: driverEnabled ?? this.driverEnabled,
  );

  final int? id;

  /// Nombre con el que se saluda en el hero.
  final String name;

  /// Modalidad de navegación, independiente de la habilitación.
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
  }) async {
    await _api.post(
      '/users/',
      authenticated: false,
      body: <String, Object?>{
        'name': name.trim(),
        'last_name': lastName.trim(),
        'phone': phone.trim(),
        'password': password,
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
      role: account.driverEnabled ? UserRole.driver : UserRole.passenger,
      activeMode: account.role,
      userId: account.id,
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

  /// `GET /auth/me`
  ///
  /// Perfil de solo lectura para la pantalla de Perfil: nombre completo,
  /// teléfono, rol y datos del vehículo. Es la misma información que devuelve
  /// el ingreso, pero siempre fresca.
  Future<UserProfile> fetchProfile() async {
    final response = await _api.get('/auth/me');
    if (response is! Map<String, dynamic>) {
      throw const ApiException('El servidor no devolvió el perfil.');
    }
    return UserProfile.fromJson(response);
  }

  /// `PATCH /users/me`
  ///
  /// Actualiza nombre, apellido y teléfono del usuario autenticado. El
  /// identificador sale del token: no hay forma de editar otra cuenta. El
  /// teléfono debe seguir siendo único en el backend.
  Future<UserProfile> updateProfile({
    required String name,
    required String lastName,
    required String phone,
  }) async {
    final response = await _api.patch(
      '/users/me',
      body: <String, Object?>{
        'name': name.trim(),
        'last_name': lastName.trim(),
        'phone': phone.trim(),
      },
    );
    if (response is! Map<String, dynamic>) {
      throw const ApiException(
        'El servidor no devolvió el perfil actualizado.',
      );
    }
    final profile = UserProfile.fromJson(response);
    // El nombre también vive en la sesión local para el saludo inicial.
    await _session.saveName(profile.name);
    return profile;
  }

  /// `PATCH /users/me/password`
  ///
  /// Cambia la contraseña después de verificar la actual. La sesión abierta
  /// sigue siendo válida hasta su vencimiento normal.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _api.patch(
      '/users/me/password',
      body: <String, Object?>{
        'current_password': currentPassword,
        'new_password': newPassword,
      },
    );
  }

  /// `PATCH /users/me/vehicle`
  ///
  /// Registra, actualiza o limpia el vehículo del conductor. Los tres campos
  /// nulos borran los datos ya guardados. Devuelve el perfil actualizado.
  Future<UserProfile> updateVehicle({
    String? model,
    String? plate,
    String? color,
    bool activate = false,
  }) async {
    final body = <String, Object?>{
      'vehicle_model': model?.trim(),
      'vehicle_plate': plate?.trim(),
      'vehicle_color': color?.trim(),
    };
    final response = activate
        ? await _api.put('/users/me/driver', body: body)
        : await _api.patch('/users/me/vehicle', body: body);
    if (response is! Map<String, dynamic>) {
      throw const ApiException(
        'El servidor no devolvió el perfil actualizado.',
      );
    }
    final profile = UserProfile.fromJson(response);
    if (activate) await _cacheMode(profile);
    return profile;
  }

  Future<UserProfile> switchTravelMode(UserRole mode) async {
    final response = await _api.patch(
      '/users/me/mode',
      body: {'mode': mode.wire},
    );
    if (response is! Map<String, dynamic>) {
      throw const ApiException('No se pudo confirmar el cambio de modo.');
    }
    final profile = UserProfile.fromJson(response);
    await _cacheMode(profile);
    return profile;
  }

  Future<void> _cacheMode(UserProfile profile) async {
    if (await _session.readUserId() == profile.id) {
      await _session.saveTravelMode(
        profile.role,
        driverEnabled: profile.driverEnabled,
      );
    }
  }

  /// `DELETE /users/me`
  ///
  /// Borra la cuenta en el backend y limpia la sesión local. El servidor
  /// rechaza la operación si hay rutas activas o solicitudes pendientes; en ese
  /// caso lanza [ApiException] con el mensaje para mostrar en la app.
  Future<void> deleteAccount() async {
    await _api.delete('/users/me');
    await _session.clear();
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
        final account = Account.fromProfile(UserProfile.fromJson(user), token);
        if (account.id != null) await _session.saveUserId(account.id!);
        await _session.saveTravelMode(
          account.role,
          driverEnabled: account.driverEnabled,
        );
        return account;
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

    return Account(
      id: await _session.readUserId(),
      name: name,
      role: role == UserRole.driver
          ? await _session.readActiveMode() ?? role
          : UserRole.passenger,
      driverEnabled: role == UserRole.driver,
      token: token,
    );
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
    return Account.fromProfile(UserProfile.fromJson(user), token);
  }
}
