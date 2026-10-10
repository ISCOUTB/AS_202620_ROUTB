import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

/// Repositorio de notificaciones push.
///
/// Gestiona el registro y eliminación de tokens FCM en el backend.
/// Cumple la regla: no hace llamadas HTTP directas; delega en [ApiClient].
class NotificationsRepository {
  const NotificationsRepository(this._client);

  final ApiClient _client;

  /// Registra o actualiza el token FCM del dispositivo en el backend.
  ///
  /// Lanza [ApiException] si la operación falla.
  Future<void> registerToken({
    required String deviceToken,
    required String platform,
  }) async {
    await _client.put(
      '/notifications/device-token',
      body: {
        'device_token': deviceToken,
        'platform': platform,
      },
    );
  }

  /// Elimina el token FCM del dispositivo en el backend.
  ///
  /// Lanza [ApiException] si el token no se encuentra o hay un error de red.
  Future<void> removeToken(String deviceToken) async {
    await _client.delete('/notifications/device-token/$deviceToken');
  }
}
