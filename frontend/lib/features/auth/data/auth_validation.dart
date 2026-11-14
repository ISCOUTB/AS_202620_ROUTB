/// Validaciones del formulario de acceso y registro.
///
/// El backend vuelve a validar y normaliza; estas funciones solo evitan enviar
/// datos que la API rechazaría y dan un mensaje claro en el campo.
library;

final RegExp _phoneSeparators = RegExp(r'[\s-]');
final RegExp _acceptedPhone = RegExp(r'^(?:\+?57)?3\d{9}$');
final RegExp _countryPrefix = RegExp(r'^\+?57');

/// Devuelve el celular en 10 dígitos, o `null` si no es válido.
String? normalizePhone(String value) {
  final compact = value.replaceAll(_phoneSeparators, '');
  if (!_acceptedPhone.hasMatch(compact)) return null;
  return compact.replaceFirst(_countryPrefix, '');
}

/// Mensaje para un teléfono inválido, o `null` si es válido.
String? validatePhone(String value) {
  if (normalizePhone(value) == null) {
    return 'Ingresa un celular colombiano de 10 dígitos';
  }
  return null;
}

/// Mensaje para una contraseña de registro inválida, o `null` si es válida.
String? validateNewPassword(String value) {
  if (value.length < 8) {
    return 'La contraseña debe tener al menos 8 caracteres';
  }
  if (value.length > 128) {
    return 'La contraseña no puede superar 128 caracteres';
  }
  return null;
}

/// Mensaje para un nombre o apellido inválido, o `null` si es válido.
String? validateName(String value, String label) {
  final trimmed = value.trim();
  if (trimmed.length < 2) {
    return 'El $label debe tener al menos 2 caracteres';
  }
  if (trimmed.length > 50) {
    return 'El $label no puede superar 50 caracteres';
  }
  return null;
}
