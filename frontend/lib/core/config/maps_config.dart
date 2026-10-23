/// Configuración de claves y parámetros para Google Maps Platform.
///
/// La clave vive en `frontend/.env` (ignorado por git) y se inyecta al
/// compilar con:
/// ```bash
/// flutter run --dart-define-from-file=.env
/// ```
/// No debe quedar una clave por defecto en el código.
class MapsConfig {
  const MapsConfig._();

  /// Clave inyectada en tiempo de compilación.
  static const String apiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
}
