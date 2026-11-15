import 'package:flutter/material.dart';

import '../theme/routb_palette.dart';
import 'routb_logo.dart';

/// Pantalla de arranque.
///
/// Se ve mientras la app resuelve si hay sesión guardada. La marca aparece
/// desde el primer cuadro, en la misma posición y tamaño que el splash nativo
/// de Android, para que el cambio no se note; el halo y el indicador entran con
/// un fundido corto. Si el sistema pide reducir el movimiento, todo aparece ya
/// en su sitio.
class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
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
    final isDark = context.isDarkMode;

    return Scaffold(
      backgroundColor: palette.background,
      body: Center(
        child: Semantics(
          container: true,
          label: 'Cargando ROUTB',
          child: ExcludeSemantics(
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                FadeTransition(
                  opacity: _fade,
                  child: Container(
                    width: 164,
                    height: 164,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: <Color>[
                          palette.brand.withValues(alpha: isDark ? 0.3 : 0.14),
                          palette.brand.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                RoutbLogo(
                  variant: RoutbLogoVariant.onSurface.forBackground(isDark),
                  width: 112,
                ),
                Transform.translate(
                  offset: const Offset(0, 102),
                  child: FadeTransition(
                    opacity: _fade,
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          palette.brand,
                        ),
                      ),
                    ),
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
