/// Fuente única de verdad para la dirección del backend de ROUTB.
///
/// Por defecto la app se comunica con el servicio desplegado en Render
/// (ver docs/adr/0005-render-plataforma-de-despliegue.md), de modo que
/// `flutter run` y `flutter build` funcionan sin argumentos adicionales.
///
/// Para desarrollar contra el backend local se sobreescribe en tiempo de
/// compilación:
///
/// ```bash
/// # Web (Flutter Web)
/// flutter run --dart-define=ROUTB_API_BASE_URL=http://127.0.0.1:8000
///
/// # Android emulador
/// flutter run --dart-define=ROUTB_API_BASE_URL=http://10.0.2.2:8000
/// ```
class ApiConfig {
  const ApiConfig._();

  /// Dirección del backend desplegado en la nube.
  ///
  /// Es el valor por defecto de todas las plataformas (Android, iOS y web).
  /// Debe terminar en HTTPS: Android tiene `usesCleartextTraffic="false"`
  /// en el manifest principal, por lo que las peticiones HTTP planas se
  /// bloquean en builds de release.
  static const String productionBaseUrl =
      'https://as-202620-routb.onrender.com';

  /// Valor inyectado con `--dart-define=ROUTB_API_BASE_URL=...`.
  /// Vacío cuando el flag no se proporciona.
  static const String _override =
      String.fromEnvironment('ROUTB_API_BASE_URL');

  /// Dirección base efectiva, sin barra final.
  static String get baseUrl =>
      _override.isEmpty ? productionBaseUrl : _override;
}