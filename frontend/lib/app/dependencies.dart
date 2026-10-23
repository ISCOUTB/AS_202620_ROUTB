import 'package:flutter/material.dart';

import '../core/network/api_client.dart';
import '../core/storage/session_store.dart';
import '../core/theme/theme_controller.dart';
import '../features/auth/data/auth_repository.dart';
import '../core/widgets/routb_toast.dart';
import '../features/auth/screens/auth_flow.dart';
import '../features/matching/data/matching_repository.dart';
import '../features/notifications/data/notifications_repository.dart';
import '../features/notifications/push_notification_service.dart';
import '../features/trips/data/trip_repository.dart';
import 'app_routes.dart';

/// Repositorios y sesión que comparten todos los módulos.
///
/// Vive en su propio archivo para que las pantallas de cada módulo puedan
/// leer las dependencias sin importar la raíz de la app.
class RoutbDependencies {
  RoutbDependencies({
    required this.session,
    required this.auth,
    required this.trips,
    required this.matching,
    required this.push,
    required this.theme,
    GlobalKey<NavigatorState>? navigatorKey,
  }) : navigatorKey = navigatorKey ?? GlobalKey<NavigatorState>();

  /// Clave global de navegación para redirecciones (ej. sesión expirada).
  final GlobalKey<NavigatorState> navigatorKey;

  /// Sesión persistida en el dispositivo.
  final SessionStore session;

  /// Ingreso, registro y cierre de sesión.
  final AuthRepository auth;

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
    final navKey = GlobalKey<NavigatorState>();

    bool handlingUnauthorized = false;
    final api = ApiClient(
      session,
      onUnauthorized: () async {
        if (handlingUnauthorized) return;
        handlingUnauthorized = true;
        await session.clear();
        final nav = navKey.currentState;
        if (nav != null && nav.mounted) {
          nav.pushAndRemoveUntil(
            RoutbPageRoute<void>(child: const AuthFlow()),
            (route) => false,
          );
          final ctx = nav.context;
          if (ctx.mounted) {
            RoutbToast.show(ctx, 'Tu sesión expiró. Ingresa de nuevo.');
          }
        }
        handlingUnauthorized = false;
      },
    );

    return RoutbDependencies(
      session: session,
      auth: AuthRepository(api, session),
      trips: TripRepository(api),
      matching: MatchingRepository(api),
      push: PushNotificationService(repository: NotificationsRepository(api)),
      theme: theme,
      navigatorKey: navKey,
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
