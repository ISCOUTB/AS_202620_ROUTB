import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/network/api_exception.dart';
import 'data/notifications_repository.dart';

/// Aviso push ya recibido por la app.
///
/// Solo expone lo necesario para reaccionar en pantalla: título, cuerpo y la
/// metadata mínima del contrato del backend. No incluye tokens ni datos de la
/// sesión.
@immutable
class RoutbPushEvent {
  const RoutbPushEvent({
    required this.title,
    required this.body,
    this.event,
    this.tripId,
    this.foreground = true,
  });

  /// Construye el evento a partir del mensaje de FCM.
  factory RoutbPushEvent.fromMessage(
    RemoteMessage message, {
    required bool foreground,
  }) {
    final data = message.data;
    return RoutbPushEvent(
      title:
          message.notification?.title ?? data['title']?.toString().trim() ?? '',
      body: message.notification?.body ?? data['body']?.toString().trim() ?? '',
      event: data['event']?.toString(),
      tripId: int.tryParse(data['trip_id']?.toString() ?? ''),
      foreground: foreground,
    );
  }

  /// Título mostrado por la notificación.
  final String title;

  /// Cuerpo mostrado por la notificación.
  final String body;

  /// Tipo de evento del backend (`request_accepted`, `trip_cancelled`, ...).
  final String? event;

  /// Viaje afectado, cuando el backend lo incluye.
  final int? tripId;

  /// `true` si llegó con la app abierta.
  final bool foreground;

  /// `true` si hay algo que mostrar al usuario.
  bool get hasContent => title.trim().isNotEmpty || body.trim().isNotEmpty;
}

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

  static const String channelUpdates = 'routb_updates';
  static const String channelNewRequests = 'routb_new_requests';

  final NotificationsRepository repository;
  FirebaseMessaging? _messagingInstance;
  FirebaseMessaging get _messaging =>
      _messagingInstance ??= FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  final StreamController<RoutbPushEvent> _events =
      StreamController<RoutbPushEvent>.broadcast();
  String? _registeredToken;
  bool _started = false;
  RoutbPushEvent? _pendingTap;
  VoidCallback? _onNotification;

  /// Avisos recibidos por la app, incluidos los que llegan en primer plano.
  ///
  /// Las pantallas se suscriben aquí para refrescar su estado y mostrar una
  /// confirmación visual, sin volver a consultar FCM ni exponer datos
  /// sensibles.
  Stream<RoutbPushEvent> get events => _events.stream;

  /// Registra el token y mantiene la sesión sincronizada cuando llega o se
  /// abre una notificación.
  ///
  /// No pide permisos al iniciar la app (G20): el Perfil muestra el estado y
  /// ofrece abrir los ajustes del sistema cuando las notificaciones están
  /// desactivadas.
  Future<void> start({required VoidCallback onNotification}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    _onNotification = onNotification;
    try {
      if (!_started) {
        await _local.initialize(
          const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          ),
          onDidReceiveNotificationResponse: _onLocalNotificationResponse,
        );
        await _ensureChannels();
        _messaging.onTokenRefresh.listen(_register);
        FirebaseMessaging.onMessage.listen((message) async {
          _emit(message, foreground: true);
          await _showForeground(message);
          onNotification();
        });
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
          _emit(message, foreground: false);
          onNotification();
        });
        _started = true;
      }
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _emit(initialMessage, foreground: false);
        onNotification();
      }
      await _register(await _messaging.getToken());
    } on Object catch (error) {
      dev.log(
        'No se pudo iniciar FCM: $error',
        name: 'PushNotificationService',
        level: 900,
      );
    }
  }

  /// Toma el último toque de notificación que llegó antes de que una pantalla
  /// escuchara el stream.
  ///
  /// Al abrir la app desde una notificación con el proceso cerrado, FCM entrega
  /// el mensaje inicial en `start()`. Si la pantalla todavía no se suscribió, el
  /// aviso se guarda aquí y la pantalla lo consume al montarse.
  RoutbPushEvent? takePendingTap() {
    final event = _pendingTap;
    _pendingTap = null;
    return event;
  }

  void _emit(RemoteMessage message, {required bool foreground}) {
    final event = RoutbPushEvent.fromMessage(message, foreground: foreground);
    _emitEvent(event);
  }

  void _emitEvent(RoutbPushEvent event) {
    if (!event.hasContent || _events.isClosed) return;
    if (_events.hasListener) {
      _events.add(event);
    } else if (!event.foreground) {
      // Solo los toques se guardan: un aviso en primer plano sin oyente no
      // debe abrir una pantalla cuando la app vuelva a montarse.
      _pendingTap = event;
    }
  }

  /// Inyecta un aviso desde una prueba sin pasar por FCM.
  @visibleForTesting
  void emitForTest(RoutbPushEvent event) => _emitEvent(event);

  /// Reacciona al toque de una notificación local mostrada en primer plano.
  ///
  /// Sin este callback, tocar el aviso mientras la app está abierta no hacía
  /// nada; ahora se emite el mismo evento que un push abierto desde segundo
  /// plano para que las pantallas naveguen igual.
  void _onLocalNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) return;
      final event = RoutbPushEvent(
        title: decoded['title']?.toString() ?? '',
        body: decoded['body']?.toString() ?? '',
        event: decoded['event']?.toString(),
        tripId: int.tryParse(decoded['trip_id']?.toString() ?? ''),
        foreground: false,
      );
      _emitEvent(event);
      _onNotification?.call();
    } on FormatException {
      // Un payload viejo o corrupto no debe tumbar la app.
    }
  }

  Future<void> _register(String? token) async {
    if (token == null || token.isEmpty) return;
    _registeredToken = token;
    await registerToken(deviceToken: token, platform: 'android');
  }

  /// Canal Android que corresponde a un evento de la API.
  ///
  /// La solicitud nueva usa un canal propio con una vibración más intensa para
  /// que el conductor la distinga del resto de avisos (G21).
  @visibleForTesting
  static String channelIdForEvent(String? event) =>
      event == 'request_created' ? channelNewRequests : channelUpdates;

  /// Detalles locales de la notificación para un evento.
  @visibleForTesting
  static NotificationDetails detailsForEvent(String? event) {
    final isNewRequest = channelIdForEvent(event) == channelNewRequests;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelIdForEvent(event),
        isNewRequest ? 'Nuevas solicitudes' : 'Actualizaciones de viajes',
        channelDescription: isNewRequest
            ? 'Avisos de pasajeros que solicitan cupo.'
            : 'Avisos sobre solicitudes y viajes.',
        importance: isNewRequest ? Importance.max : Importance.high,
        priority: isNewRequest ? Priority.max : Priority.high,
        enableVibration: isNewRequest,
        vibrationPattern: isNewRequest
            ? Int64List.fromList(<int>[0, 500, 200, 500])
            : null,
      ),
    );
  }

  Future<void> _ensureChannels() async {
    try {
      final android = _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android == null) return;
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          channelUpdates,
          'Actualizaciones de viajes',
          description: 'Avisos sobre solicitudes y viajes.',
          importance: Importance.high,
        ),
      );
      await android.createNotificationChannel(
        AndroidNotificationChannel(
          channelNewRequests,
          'Nuevas solicitudes',
          description: 'Avisos de pasajeros que solicitan cupo.',
          importance: Importance.max,
          enableVibration: true,
          vibrationPattern: Int64List.fromList(<int>[0, 500, 200, 500]),
        ),
      );
    } on Object catch (error) {
      dev.log(
        'No se pudieron crear los canales de notificación: $error',
        name: 'PushNotificationService',
        level: 900,
      );
    }
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    final event = message.data['event'];
    final payload = jsonEncode(<String, Object?>{
      'title': notification.title ?? '',
      'body': notification.body ?? '',
      'event': event is String ? event : null,
      'trip_id': message.data['trip_id'],
    });
    await _local.show(
      notification.hashCode,
      notification.title,
      notification.body,
      detailsForEvent(event is String ? event : null),
      payload: payload,
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

  /// Cierra el flujo de avisos al desmontar la aplicación o las pruebas.
  void dispose() {
    _events.close();
  }

  /// Desvincula y rota el token FCM antes de cerrar sesión.
  Future<void> logout() async {
    _pendingTap = null;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (!_started) return;
    try {
      final token = _registeredToken ?? await _messaging.getToken();
      if (token != null) await removeToken(token);
      await _messaging.deleteToken();
      _registeredToken = null;
    } on Object catch (error) {
      dev.log(
        'No se pudo desvincular FCM al salir: $error',
        name: 'PushNotificationService',
        level: 900,
      );
    }
  }
}
