/// Configuración de claves y parámetros para Google Maps Platform.
///
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
}
