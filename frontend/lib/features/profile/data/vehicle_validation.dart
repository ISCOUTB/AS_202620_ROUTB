/// Validaciones del formulario de vehículo del conductor.
///
/// El backend vuelve a validar y normaliza la placa; estas funciones solo
/// evitan enviar datos que la API rechazaría y dan un mensaje claro en el
/// campo.
library;

final RegExp _plateSeparators = RegExp(r'[\s-]');
final RegExp _acceptedPlate = RegExp(r'^[A-Z]{3}\d{3}$');

/// Devuelve la placa en formato `ABC-123`, o `null` si no es válida.
String? normalizeVehiclePlate(String value) {
  final compact = value.trim().toUpperCase().replaceAll(_plateSeparators, '');
  if (!_acceptedPlate.hasMatch(compact)) return null;
  return '${compact.substring(0, 3)}-${compact.substring(3)}';
}

/// Mensaje para una placa inválida, o `null` si es válida.
String? validateVehiclePlate(String value) {
  if (normalizeVehiclePlate(value) == null) {
    return 'Ingresa una placa colombiana válida (ej. ABC-123)';
  }
  return null;
}

/// Mensaje para un modelo inválido, o `null` si es válido.
String? validateVehicleModel(String value) {
  final trimmed = value.trim();
  if (trimmed.length < 2) {
    return 'El modelo debe tener al menos 2 caracteres';
  }
  if (trimmed.length > 50) {
    return 'El modelo no puede superar 50 caracteres';
  }
  return null;
}

/// Mensaje para un color inválido, o `null` si es válido.
String? validateVehicleColor(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return 'Ingresa el color del vehículo';
  }
  if (trimmed.length < 2) {
    return 'El color debe tener al menos 2 caracteres';
  }
  if (trimmed.length > 30) {
    return 'El color no puede superar 30 caracteres';
  }
  return null;
}
