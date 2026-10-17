import 'package:flutter/foundation.dart';

import 'initials.dart';
import 'user_role.dart';

/// Perfil de solo lectura de la persona que entró, según `GET /auth/me`.
///
/// El backend todavía no permite editar estos datos ni cambiar la contraseña:
/// la pantalla de Perfil solo los muestra, junto con el estado del
/// consentimiento de ubicación.
@immutable
class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.lastName,
    required this.phone,
    required this.role,
    this.locationConsentAt,
  });

  /// Identificador de la cuenta.
  final int id;

  /// Nombre de pila.
  final String name;

  /// Apellido.
  final String lastName;

  /// Teléfono con el que se entra.
  final String phone;

  /// Rol con el que se registró; no se puede cambiar desde la app.
  final UserRole role;

  /// Fecha en que otorgó el consentimiento de ubicación, o `null` si no lo ha
  /// otorgado.
  final DateTime? locationConsentAt;

  /// Nombre completo para el encabezado y el avatar.
  String get fullName => '$name $lastName'.trim();

  /// Iniciales para el avatar.
  String get initials => initialsOf(fullName);

  /// Nombre del rol para la insignia: «Pasajero» o «Conductor».
  String get roleLabel => role == UserRole.driver ? 'Conductor' : 'Pasajero';

  /// `true` si el consentimiento de ubicación está vigente.
  bool get hasLocationConsent => locationConsentAt != null;

  /// Estado del consentimiento de ubicación: «Autorizado» o «Sin autorizar».
  String get consentLabel =>
      hasLocationConsent ? 'Autorizado' : 'Sin autorizar';

  /// Copia con el consentimiento de ubicación sustituido.
  ///
  /// La usa el perfil al autorizar o revocar: el endpoint acaba de confirmar
  /// el cambio (204) y no hace falta volver a leer todo el perfil para
  /// reflejarlo.
  UserProfile withLocationConsent(DateTime? at) => UserProfile(
    id: id,
    name: name,
    lastName: lastName,
    phone: phone,
    role: role,
    locationConsentAt: at,
  );

  /// Lee el perfil que devuelve `GET /auth/me`.
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rawConsent = json['location_consent_at'] as String?;
    return UserProfile(
      id: json['id'] as int? ?? 0,
      name: (json['name'] as String?)?.trim() ?? '',
      lastName: (json['last_name'] as String?)?.trim() ?? '',
      phone: (json['phone'] as String?)?.trim() ?? '',
      role: UserRole.fromWire(json['role'] as String?),
      // La fecha viaja con el desfase de Colombia; se pasa a la hora del
      // dispositivo para mostrarla en el mismo huso que el resto de la app.
      locationConsentAt: rawConsent == null
          ? null
          : DateTime.tryParse(rawConsent)?.toLocal(),
    );
  }
}
