import 'package:flutter/material.dart';

import '../theme/routb_palette.dart';
import 'routb_logo.dart';

/// Pantalla de arranque.
///
/// Se ve mientras la app resuelve si hay sesión guardada: el lockup entra con
/// escala y fundido y debajo gira el indicador. Si el sistema pide reducir el
/// movimiento, el logo aparece ya en su sitio.
class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );

  late final Animation<double> _scale = Tween<double>(
    begin: 0.78,
    end: 1,
  ).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      return;
    }
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.background,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RoutbLogo(
                  variant: context.isDarkMode
                      ? RoutbLogoVariant.onHero
                      : RoutbLogoVariant.onSurface,
                  width: 118,
                  height: 128,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(palette.ink),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}