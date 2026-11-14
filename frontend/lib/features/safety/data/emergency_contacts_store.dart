import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/emergency_contact.dart';

/// Guarda hasta tres contactos de emergencia en el dispositivo.
///
/// No hay backend ni permiso de contactos: el nombre y el teléfono se escriben
/// a mano, y se conservan al cerrar la app. La clave es única del dispositivo,
/// no de la cuenta, para que sigan ahí aunque la sesión se cierre.
class EmergencyContactsStore {
  const EmergencyContactsStore();

  /// Clave de `shared_preferences`.
  static const String storageKey = 'routb.emergency_contacts.v1';

  /// Límite del sprint.
  static const int maxContacts = 3;

  Future<List<EmergencyContact>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.trim().isEmpty) return const <EmergencyContact>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <EmergencyContact>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(EmergencyContact.fromJson)
          .where((contact) => contact.id.isNotEmpty && contact.phone.isNotEmpty)
          .take(maxContacts)
          .toList(growable: false);
    } on FormatException {
      return const <EmergencyContact>[];
    }
  }

  Future<void> save(List<EmergencyContact> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      storageKey,
      jsonEncode(
        contacts.take(maxContacts).map((contact) => contact.toJson()).toList(),
      ),
    );
  }
}

/// Valida el nombre de un contacto. Devuelve `null` si es correcto.
String? validateContactName(String raw) {
  final name = raw.trim();
  if (name.isEmpty) return 'Escribe el nombre del contacto.';
  if (name.length > 60) return 'Usa un nombre de 60 caracteres o menos.';
  return null;
}

/// Valida el teléfono de un contacto. Devuelve `null` si es correcto.
///
/// Acepta números nacionales e internacionales: entre 7 y 15 dígitos, con un
/// `+` opcional al principio. Los espacios y guiones se ignoran.
String? validateContactPhone(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 7) {
    return 'Escribe un teléfono de al menos 7 dígitos.';
  }
  if (digits.length > 15) {
    return 'El teléfono no puede tener más de 15 dígitos.';
  }
  final plus = raw.indexOf('+');
  if (plus > 0) {
    return 'El + solo puede ir al principio del número.';
  }
  return null;
}
