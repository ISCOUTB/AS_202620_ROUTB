import 'package:flutter/foundation.dart';

import 'initials.dart';
import 'user_role.dart';

/// Perfil de la persona que entró, según `GET /auth/me`.
///
/// Nombre, apellido y teléfono se editan con `PATCH /users/me`; la contraseña
/// se cambia con `PATCH /users/me/password`.
@immutable
class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.lastName,
    required this.phone,
    required this.role,
    this.vehicleModel,
    this.vehiclePlate,
    this.vehicleColor,
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

  /// Marca y línea del vehículo, solo para conductores.
  final String? vehicleModel;

  /// Placa colombiana del vehículo, ya normalizada por el backend.
  final String? vehiclePlate;

  /// Color del vehículo.
  final String? vehicleColor;

  /// Nombre completo para el encabezado y el avatar.
  String get fullName => '$name $lastName'.trim();

  /// Iniciales para el avatar.
  String get initials => initialsOf(fullName);

  /// Nombre del rol para la insignia: «Pasajero» o «Conductor».
  String get roleLabel => role == UserRole.driver ? 'Conductor' : 'Pasajero';

  /// `true` si el conductor ya registró algún dato del vehículo.
  bool get hasVehicle =>
      (vehicleModel ?? '').trim().isNotEmpty ||
      (vehiclePlate ?? '').trim().isNotEmpty ||
      (vehicleColor ?? '').trim().isNotEmpty;

  /// `true` si modelo, placa y color están completos (requisito de N2).
  bool get hasCompleteVehicle =>
      (vehicleModel ?? '').trim().isNotEmpty &&
      (vehiclePlate ?? '').trim().isNotEmpty &&
      (vehicleColor ?? '').trim().isNotEmpty;

  /// Campos del vehículo que faltan, para el estado «Pendiente» de la tarjeta.
  List<String> get missingVehicleFields => <String>[
    if ((vehicleModel ?? '').trim().isEmpty) 'modelo',
    if ((vehicleColor ?? '').trim().isEmpty) 'color',
    if ((vehiclePlate ?? '').trim().isEmpty) 'placa',
  ];

  /// Ficha corta del vehículo para la tarjeta del perfil.
  String get vehicleLabel {
    final model = (vehicleModel ?? '').trim();
    final color = (vehicleColor ?? '').trim();
    final plate = (vehiclePlate ?? '').trim();
    final head = [model, color].where((part) => part.isNotEmpty).join(' · ');
    if (head.isNotEmpty && plate.isNotEmpty) return '$head ($plate)';
    return head.isNotEmpty ? head : plate;
  }

  /// Copia con los datos del vehículo sustituidos.
  UserProfile withVehicle({String? model, String? plate, String? color}) =>
      UserProfile(
        id: id,
        name: name,
        lastName: lastName,
        phone: phone,
        role: role,
        vehicleModel: model,
        vehiclePlate: plate,
        vehicleColor: color,
      );

  /// Lee el perfil que devuelve `GET /auth/me`.
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as int? ?? 0,
      name: (json['name'] as String?)?.trim() ?? '',
      lastName: (json['last_name'] as String?)?.trim() ?? '',
      phone: (json['phone'] as String?)?.trim() ?? '',
      role: UserRole.fromWire(json['role'] as String?),
      vehicleModel: (json['vehicle_model'] as String?)?.trim(),
      vehiclePlate: (json['vehicle_plate'] as String?)?.trim(),
      vehicleColor: (json['vehicle_color'] as String?)?.trim(),
    );
  }
}
