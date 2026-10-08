import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_role.dart';

/// Sesión de la persona que usa la app, persistida en el dispositivo.
///
/// Guarda el token de acceso, el nombre, el rol y el modo del tema. El token
/// se escribe con la misma clave que usaba la versión anterior de la app para
/// no invalidar sesiones ya abiertas.
class SessionStore {
  SessionStore([this._preferences]);

  static const String _tokenKey = 'routb_access_token';
  static const String _nameKey = 'routb_name';
  static const String _roleKey = 'routb_role';
  static const String _themeKey = 'routb_theme_mode';
  static const String _locationConsentPromptedKey =
      'routb_location_consent_prompted';

  SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async =>
      _preferences ??= await SharedPreferences.getInstance();

  /// Token JWT vigente, o `null` si no hay sesión iniciada.
  Future<String?> readToken() async {
    final token = (await _prefs).getString(_tokenKey);
    return (token == null || token.isEmpty) ? null : token;
  }

  /// Nombre con el que se saluda en el hero.
  Future<String?> readName() async => (await _prefs).getString(_nameKey);

  /// Rol con el que entró.
  Future<UserRole?> readRole() async {
    final raw = (await _prefs).getString(_roleKey);
    return raw == null ? null : UserRole.fromWire(raw);
  }

  /// Guarda la sesión tras un ingreso o un registro exitoso.
  Future<void> save({
    required String token,
    required String name,
    required UserRole role,
  }) async {
    final prefs = await _prefs;
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_nameKey, name);
    await prefs.setString(_roleKey, role.wire);
  }

  /// Cierra la sesión y borra los datos de la persona.
  Future<void> clear() async {
    final prefs = await _prefs;
    await prefs.remove(_tokenKey);
    await prefs.remove(_nameKey);
    await prefs.remove(_roleKey);
  }

  /// Indica si ya se mostró la explicación de ubicación en este dispositivo.
  Future<bool> readLocationConsentPrompted() async =>
      (await _prefs).getBool(_locationConsentPromptedKey) ?? false;

  /// Evita volver a interrumpir el inicio después de responder al aviso.
  Future<void> saveLocationConsentPrompted() async {
    await (await _prefs).setBool(_locationConsentPromptedKey, true);
  }

  /// Modo del tema elegido. Por defecto sigue al sistema.
  Future<ThemeMode> readThemeMode() async {
    final raw = (await _prefs).getString(_themeKey);
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == raw,
      orElse: () => ThemeMode.system,
    );
  }

  /// Guarda el modo del tema.
  Future<void> saveThemeMode(ThemeMode mode) async {
    await (await _prefs).setString(_themeKey, mode.name);
  }

  /// Libera la instancia de preferencias. Útil en pruebas.
  void dispose() => _preferences = null;
}
