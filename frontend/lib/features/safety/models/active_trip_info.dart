import 'package:flutter/foundation.dart';

/// Datos mínimos de un viaje activo para el mensaje de emergencia.
@immutable
class ActiveTripInfo {
  const ActiveTripInfo({
    required this.origin,
    required this.destination,
    required this.departureLabel,
  });

  /// Punto de salida.
  final String origin;

  /// Punto de llegada.
  final String destination;

  /// Hora de salida ya formateada.
  final String departureLabel;

  /// Trayecto en una línea.
  String get routeLabel => '$origin → $destination';
}

/// Mensaje que se prellenará en WhatsApp o SMS.
///
/// La app no envía nada: solo deja el texto listo y la persona toca enviar.
String emergencyContactMessage({
  required String userName,
  ActiveTripInfo? activeTrip,
}) {
  final name = userName.trim().isEmpty ? 'un estudiante' : userName.trim();
  final base = 'Hola, soy $name. Estoy usando ROUTB';
  if (activeTrip == null) {
    return '$base y quiero avisarte por seguridad.';
  }
  return '$base. Voy en un viaje de ${activeTrip.origin} a '
      '${activeTrip.destination}, con salida ${activeTrip.departureLabel}. '
      'Te aviso por seguridad.';
}

/// Mensaje que se prellenará al escribirle al equipo de soporte.
String supportMessage({required String userName, required String roleLabel}) {
  final name = userName.trim().isEmpty ? 'un estudiante' : userName.trim();
  return 'Hola, soy $name ($roleLabel). Necesito ayuda con ROUTB.';
}
