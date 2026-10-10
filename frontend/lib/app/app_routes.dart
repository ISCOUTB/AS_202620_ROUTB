import 'dart:async';

import 'package:flutter/material.dart';

import '../app/dependencies.dart';
import '../core/models/user_role.dart';
import '../core/theme/routb_motion.dart';
import '../core/widgets/location_consent_dialog.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/driver/screens/driver_screen.dart';
import '../features/passenger/screens/passenger_screen.dart';

/// Transición de página de ROUTB.
///
/// Reproduce el carrusel del diseño: la vista entrante se desliza desde la
/// derecha hasta su sitio y la saliente se va un 28 % hacia la izquierda, como
/// los `.vw.nxt` y `.vw.pre` del prototipo.
///
/// Con movimiento reducido se limita a un fundido.
class RoutbSlideTransitionsBuilder extends PageTransitionsBuilder {
  const RoutbSlideTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return RoutbSlideTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}

/// Deslizamiento reutilizable, sin depender de la ruta que lo contiene.
class RoutbSlideTransition extends StatelessWidget {
  const RoutbSlideTransition({
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
    super.key,
  });

  /// Progreso de entrada.
  final Animation<double> animation;

  /// Progreso de salida de la vista anterior.
  final Animation<double> secondaryAnimation;

  /// Vista que se mueve.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return FadeTransition(opacity: animation, child: child);
    }

    final entering = CurvedAnimation(
      parent: animation,
      curve: RoutbMotion.standard,
      reverseCurve: Curves.easeIn,
    );
    final leaving = CurvedAnimation(
      parent: secondaryAnimation,
      curve: RoutbMotion.standard,
    );

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(entering),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-0.28, 0),
        ).animate(leaving),
        child: child,
      ),
    );
  }
}

/// Página con el deslizamiento del diseño.
class RoutbPageRoute<T> extends PageRouteBuilder<T> {
  RoutbPageRoute({required Widget child})
    : super(
        transitionDuration: RoutbMotion.view,
        reverseTransitionDuration: RoutbMotion.view,
        pageBuilder: (context, _, _) => child,
        transitionsBuilder: (_, animation, secondaryAnimation, routeChild) =>
            RoutbSlideTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              child: routeChild,
            ),
      );
}

/// Fábrica de rutas por defecto de la app.
///
/// Flutter 3.47 sustituyó `pageTransitionsTheme` de `MaterialApp` por
/// `pageRouteBuilder`, así que el deslizamiento de ROUTB se aplica desde aquí a
/// cualquier `Navigator.push` que no elija una ruta concreta.
PageRoute<T> routbPageRoute<T>(RouteSettings settings, WidgetBuilder builder) {
  return PageRouteBuilder<T>(
    settings: settings,
    transitionDuration: RoutbMotion.view,
    reverseTransitionDuration: RoutbMotion.view,
    pageBuilder: (context, _, _) => builder(context),
    transitionsBuilder: (_, animation, secondaryAnimation, child) =>
        RoutbSlideTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          child: child,
        ),
  );
}

/// Página con un fundido corto, para cambiar de una pantalla completa a otra.
class RoutbFadeRoute<T> extends PageRouteBuilder<T> {
  RoutbFadeRoute({required Widget child})
    : super(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, _, _) => child,
        transitionsBuilder: (_, animation, _, routeChild) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
          child: routeChild,
        ),
      );
}

/// Elige la pantalla del modo que corresponde a la cuenta.
///
/// ```dart
/// Navigator.pushReplacement(
///   context,
///   RoutbFadeRoute(child: ModeRoute(account: account)),
/// );
/// ```
class ModeRoute extends StatefulWidget {
  const ModeRoute({required this.account, super.key});

  /// Cuenta que acaba de ingresar o registrarse.
  final Account account;

  @override
  State<ModeRoute> createState() => _ModeRouteState();
}

class _ModeRouteState extends State<ModeRoute> {
  bool _checked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_checked) return;
    _checked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _askForLocationConsent();
    });
  }

  Future<void> _askForLocationConsent() async {
    final dependencies = RoutbScopeDependencies.of(context);
    unawaited(dependencies.push.start(onNotification: () {
      dependencies.requestRefresh.value++;
    }));
    if (await dependencies.session.readLocationConsentPrompted()) return;
    if (!mounted) return;

    final accepted = await LocationConsentDialog.show(context);
    await dependencies.session.saveLocationConsentPrompted();
    if (!accepted || !mounted) return;

    try {
      await dependencies.auth.grantLocationConsent();
    } on Exception catch (error, stack) {
      debugPrint('ROUTB · no se pudo registrar el consentimiento: $error');
      debugPrintStack(stackTrace: stack, label: 'consentimiento');
    }
  }

  @override
  Widget build(BuildContext context) => switch (widget.account.role) {
    UserRole.driver => DriverScreen(account: widget.account),
    UserRole.passenger => PassengerScreen(account: widget.account),
  };
}
