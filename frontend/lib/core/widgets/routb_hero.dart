import 'package:flutter/material.dart';

import '../theme/routb_palette.dart';
import '../theme/routb_text.dart';
import '../theme/routb_theme.dart';
import '../theme/theme_controller.dart';

/// Barra superior del hero: saludo.
///
/// Es la misma en los dos modos; solo cambia el gesto de saludo.
class HeroBar extends StatelessWidget {
  const HeroBar({required this.userName, this.wave = false, super.key});

  /// Nombre de la persona.
  final String userName;

  /// Añade el gesto de saludo tras el nombre.
  final bool wave;

  @override
  Widget build(BuildContext context) {
    return Text(
      wave ? 'Hola, $userName 👋' : 'Hola, $userName',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: RoutbText.headline(22, color: Colors.white),
    );
  }
}

/// Interruptor de tema claro y oscuro.
///
/// El diseño original trae el tema oscuro completo pero sin botón visible; este
/// es el control que lo hace alcanzable desde la app.
class ThemeToggle extends StatelessWidget {
  const ThemeToggle({this.onDarkBackground = true, super.key});

  /// `true` si vive sobre el hero, donde el icono va en blanco.
  final bool onDarkBackground;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final foreground = onDarkBackground ? Colors.white : context.palette.brand;

    return Semantics(
      button: true,
      label: isDark ? 'Cambiar a tema claro' : 'Cambiar a tema oscuro',
      child: Material(
        color: onDarkBackground ? const Color(0x24FFFFFF) : null,
        borderRadius: BorderRadius.circular(RoutbTheme.radiusControl),
        child: InkWell(
          borderRadius: BorderRadius.circular(RoutbTheme.radiusControl),
          onTap: () =>
              RoutbScope.of(context).toggle(Theme.of(context).brightness),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              size: 18,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}
