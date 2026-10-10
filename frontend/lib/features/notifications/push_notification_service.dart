import 'dart:developer' as dev;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/network/api_exception.dart';
import 'data/notifications_repository.dart';


/// Servicio de notificaciones push.
///
/// Abstrae la lógica de registrar y eliminar el token FCM del dispositivo.
/// Las pantallas no deben importar [NotificationsRepository] directamente.
///
/// **Uso típico** (después de hacer login exitoso):
/// ```dart
/// await PushNotificationService(repository: repo)
///     .registerToken(deviceToken: token, platform: 'android');
/// ```
class PushNotificationService {
  PushNotificationService({required this.repository});

  final NotificationsRepository repository;
  FirebaseMessaging? _messagingInstance;
  FirebaseMessaging get _messaging =>
      _messagingInstance ??= FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  String? _registeredToken;
  bool _started = false;

  /// Solicita permiso en Android 13+, registra el token y mantiene la sesión
  /// sincronizada cuando llega o se abre una notificación.
  Future<void> start({required VoidCallback onNotification}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      if (!_started) {
        await _messaging.requestPermission(alert: true, badge: true, sound: true);
        await _local.initialize(
          const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          ),
        );
        _messaging.onTokenRefresh.listen(_register);
        FirebaseMessaging.onMessage.listen((message) async {
          await _showForeground(message);
          onNotification();
        });
        FirebaseMessaging.onMessageOpenedApp.listen((_) => onNotification());
        _started = true;
      }
      if (await _messaging.getInitialMessage() != null) onNotification();
      await _register(await _messaging.getToken());
    } on Object catch (error) {
      dev.log('No se pudo iniciar FCM: $error', name: 'PushNotificationService', level: 900);
    }
  }

  Future<void> _register(String? token) async {
    if (token == null || token.isEmpty) return;
    _registeredToken = token;
    await registerToken(deviceToken: token, platform: 'android');
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await _local.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'routb_updates',
          'Actualizaciones de viajes',
          channelDescription: 'Avisos sobre solicitudes y viajes.',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  /// Registra el token FCM del dispositivo en el backend.
  ///
  /// Los errores de red se registran en el log pero no se re-lanzan, para no
  /// bloquear el flujo de inicio de sesión si el backend de notificaciones
  /// no está disponible.
  Future<void> registerToken({
    required String deviceToken,
    required String platform,
  }) async {
    try {
      await repository.registerToken(
        deviceToken: deviceToken,
        platform: platform,
      );
      dev.log(
        'Token FCM registrado correctamente.',
        name: 'PushNotificationService',
      );
    } on ApiException catch (e) {
      dev.log(
        'No se pudo registrar el token FCM: ${e.message}',
        name: 'PushNotificationService',
        level: 900, // WARNING
      );
    } catch (e) {
      dev.log(
        'Error inesperado registrando token FCM: $e',
        name: 'PushNotificationService',
        level: 900,
      );
    }
  }

  /// Elimina el token FCM del backend al cerrar sesión.
  ///
  /// Los errores se registran pero no interrumpen el logout.
  Future<void> removeToken(String deviceToken) async {
    try {
      await repository.removeToken(deviceToken);
      dev.log(
        'Token FCM eliminado correctamente.',
        name: 'PushNotificationService',
      );
    } on ApiException catch (e) {
      dev.log(
        'No se pudo eliminar el token FCM: ${e.message}',
        name: 'PushNotificationService',
        level: 900,
      );
    } catch (e) {
      dev.log(
        'Error inesperado eliminando token FCM: $e',
        name: 'PushNotificationService',
        level: 900,
      );
    }
  }

  /// Desvincula y rota el token FCM antes de cerrar sesión.
  Future<void> logout() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (!_started) return;
    try {
      final token = _registeredToken ?? await _messaging.getToken();
      if (token != null) await removeToken(token);
      await _messaging.deleteToken();
      _registeredToken = null;
    } on Object catch (error) {
      dev.log('No se pudo desvincular FCM al salir: $error', name: 'PushNotificationService', level: 900);
    }
  }
}
