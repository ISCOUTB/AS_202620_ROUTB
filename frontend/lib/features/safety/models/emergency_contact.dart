import 'package:flutter/foundation.dart';

import '../../../core/models/initials.dart';

/// Contacto de emergencia guardado solo en el dispositivo.
@immutable
class EmergencyContact {
  const EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
  });

  /// Identificador local; no viaja al backend.
  final String id;

  /// Nombre con el que se reconoce el contacto.
  final String name;

  /// Teléfono tal como lo escribió la persona.
  final String phone;

  /// Iniciales para el avatar.
  String get initials => initialsOf(name);

  /// Copia con los campos indicados sustituidos.
  EmergencyContact copyWith({String? name, String? phone}) => EmergencyContact(
    id: id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'phone': phone,
  };

  factory EmergencyContact.fromJson(Map<String, dynamic> json) =>
      EmergencyContact(
        id: (json['id'] as String?)?.trim() ?? '',
        name: (json['name'] as String?)?.trim() ?? '',
        phone: (json['phone'] as String?)?.trim() ?? '',
      );
}
