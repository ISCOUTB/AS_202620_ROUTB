/// Configuración de claves y parámetros para Google Maps Platform.
///
<<<<<<< HEAD
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
=======
/// La API Key se puede sobreescribir en tiempo de compilación con:
/// ```bash
/// flutter run --dart-define=GOOGLE_MAPS_API_KEY=...
/// ```
class MapsConfig {
  const MapsConfig._();

  /// Llave por defecto suministrada para el proyecto estudiantil ROUTB.
  static const String _defaultApiKey =
      'AIzaSyCcthCBu7x_0nsXMncjrXsnH_WsR1sByvA';

  /// Llave inyectada en compilación, o [_defaultApiKey] si no se especifica.
  static const String apiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: _defaultApiKey,
  );

  /// Indica si la llave de Google Maps está activa.
  static bool get hasApiKey => apiKey.isNotEmpty;
>>>>>>> origin/master
}
