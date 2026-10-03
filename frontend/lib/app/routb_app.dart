import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/network/api_exception.dart';
import '../core/theme/routb_theme.dart';
import '../core/theme/theme_controller.dart';
import '../core/widgets/routb_splash.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/screens/auth_flow.dart';
import 'app_routes.dart';
import 'dependencies.dart';

/// Raíz de ROUTB.
///
/// Monta el [MaterialApp] con los dos temas, publica el controlador del tema y
/// las dependencias compartidas, y decide si la app arranca en el acceso o
/// directamente en la pantalla del modo que le corresponde.
class RoutbApp extends StatelessWidget {
  const RoutbApp({required this.dependencies, super.key});

  /// Repositorios y sesión que usa el árbol de widgets.
  final RoutbDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    return RoutbScope(
      controller: dependencies.theme,
      child: ListenableBuilder(
        listenable: dependencies.theme,
        builder: (context, _) {
          // El scope va POR FUERA del `MaterialApp`, no dentro de `home`.
          // `SessionGate` reemplaza su propia ruta con `pushReplacement`, así que
          // si el scope viviera en `home` desaparecería del árbol y ninguna
          // pantalla posterior podría leer las dependencias.
          return RoutbScopeDependencies(
            dependencies: dependencies,
            child: MaterialApp(
              title: 'ROUTB',
              debugShowCheckedModeBanner: false,
              theme: RoutbTheme.light(),
              darkTheme: RoutbTheme.dark(),
              themeMode: dependencies.theme.mode,
              themeAnimationDuration: const Duration(milliseconds: 320),
              themeAnimationCurve: Curves.easeOut,
              builder: (context, child) {
                // Las barras del sistema siguen a la paleta para que no queden
                // barras grises encima del hero.
                final brightness = Theme.of(context).brightness;
                return AnnotatedRegion<SystemUiOverlayStyle>(
                  value: RoutbTheme.overlayStyleFor(brightness),
                  child: ColoredBox(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: child ?? const SizedBox.shrink(),
                  ),
                );
              },
              home: const SessionGate(),
            ),
          );
        },
      ),
    );
  }
}

/// Decide la pantalla de arranque.
///
/// Si hay una sesión guardada entra directo al modo que le corresponde; si no,
/// al acceso. Mientras resuelve se ve el splash.
class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    unawaited(_resolve());
  }

  Future<void> _resolve() async {
    final dependencies = RoutbScopeDependencies.of(context);

    Account? account;
    try {
      account = await dependencies.auth.restore();
    } on Exception catch (error, stack) {
      // Una sesión ilegible no debe impedir entrar: se empieza de cero, pero
      // queda registrado por qué.
      logFailure('la restauración de sesión', error, stack);
      account = null;
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      account == null
          ? RoutbPageRoute<void>(child: const AuthFlow())
          : RoutbFadeRoute<void>(child: ModeRoute(account: account)),
    );
  }

  @override
  Widget build(BuildContext context) => const SplashView();
}