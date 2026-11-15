/// Datos del canal de soporte.
///
/// El canal todavía no está definido en el sprint, así que los dos valores
/// quedan vacíos y la pantalla muestra los botones con un aviso claro. Cuando
/// el equipo decida el número o el correo, se completan aquí y no hay que tocar
/// la interfaz.
abstract final class SupportConfig {
  /// Número de WhatsApp del equipo, con indicador de país si es necesario.
  static const String whatsappNumber = '';

  /// Correo del equipo de soporte.
  static const String email = '';

  /// `true` si ya hay un número configurado.
  static bool get hasWhatsApp => whatsappNumber.trim().isNotEmpty;

  /// `true` si ya hay un correo configurado.
  static bool get hasEmail => email.trim().isNotEmpty;
}
