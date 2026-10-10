import 'package:flutter/material.dart';

import '../core/network/api_client.dart';
import '../core/storage/session_store.dart';
import '../core/theme/theme_controller.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/matching/data/matching_repository.dart';
import '../features/notifications/data/notifications_repository.dart';
import '../features/notifications/push_notification_service.dart';
import '../features/trips/data/geocode_repository.dart';
import '../features/trips/data/trip_repository.dart';

/// Repositorios y sesión que comparten todos los módulos.
///
/// Vive en su propio archivo para que las pantallas de cada módulo puedan
/// leer las dependencias sin importar la raíz de la app.
class RoutbDependencies {
  RoutbDependencies({
    required this.session,
    required this.auth,
    required this.geocode,
    required this.trips,
    required this.matching,
    required this.push,
    required this.theme,
  });

  /// Sesión persistida en el dispositivo.
  final SessionStore session;

  /// Ingreso, registro y cierre de sesión.
  final AuthRepository auth;

  /// Búsqueda de direcciones y coordenadas exactas.
  final GeocodeRepository geocode;

  /// Viajes y solicitudes de cupo.
  final TripRepository trips;

  /// Sugerencias de viajes por compatibilidad geográfica y horaria.
  final MatchingRepository matching;

  /// Registro de token y recepción de avisos FCM.
  final PushNotificationService push;

  /// Señal para que las pantallas vuelvan a consultar solicitudes y viajes.
  final ValueNotifier<int> requestRefresh = ValueNotifier<int>(0);

  /// Controlador del modo claro u oscuro.
  final ThemeController theme;

  /// Monta las dependencias reales.
  ///
  /// [ThemeController] se carga con el modo ya guardado, de modo que la
  /// primera pantalla sale directamente en el tema correcto.
  static Future<RoutbDependencies> live() async {
    final session = SessionStore();
    final theme = await ThemeController.load(session);
    final api = ApiClient(session);
    return RoutbDependencies(
      session: session,
      auth: AuthRepository(api, session),
      geocode: GeocodeRepository(api),
      trips: TripRepository(api),
      matching: MatchingRepository(api),
      push: PushNotificationService(repository: NotificationsRepository(api)),
      theme: theme,
    );
  }

  /// Cierra los recursos que consumen sistema.
  void dispose() {
    requestRefresh.dispose();
    theme.dispose();
  }
}

/// Publica las dependencias en el árbol de widgets.
class RoutbScopeDependencies extends InheritedWidget {
  const RoutbScopeDependencies({
    required this.dependencies,
    required super.child,
    super.key,
  });

  /// Dependencias disponibles para el subárbol.
  final RoutbDependencies dependencies;

  /// Dependencias del contexto dado.
  ///
  /// ```dart
  /// final trips = RoutbScopeDependencies.of(context).trips;
  /// ```
  static RoutbDependencies of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<RoutbScopeDependencies>();
    assert(scope != null, 'No hay RoutbScopeDependencies en el árbol.');
    return scope!.dependencies;
  }

  @override
  bool updateShouldNotify(RoutbScopeDependencies oldWidget) =>
      oldWidget.dependencies != dependencies;
}
