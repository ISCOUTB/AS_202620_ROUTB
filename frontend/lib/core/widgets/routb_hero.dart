import 'package:flutter/material.dart';

import '../models/user_role.dart';
import '../theme/routb_palette.dart';
import '../theme/routb_text.dart';
import '../theme/routb_theme.dart';
import '../theme/theme_controller.dart';
import 'routb_logo.dart';

/// Barra superior del hero: logo, saludo y acciones.
///
/// Es la misma en los dos modos; lo que cambia es la etiqueta de modo y el
/// gesto de saludo.
class HeroBar extends StatelessWidget {
  const HeroBar({
    required this.role,
    required this.userName,
    required this.onLogout,
    this.onLocationPrivacy,
    required this.isDarkBackground,
    this.wave = false,
    super.key,
  });

  /// Perfil de quien entró.
  final UserRole role;

  /// Nombre de la persona.
  final String userName;

  /// Acción de cerrar sesión.
  final VoidCallback onLogout;
  final VoidCallback? onLocationPrivacy;

  /// `true` si el hero se pinta en tema oscuro.
  final bool isDarkBackground;

  /// Añade el gesto de saludo tras el nombre.
  final bool wave;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0x24FFFFFF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: RoutbLogo(
            variant: isDarkBackground
                ? RoutbLogoVariant.onHero
                : RoutbLogoVariant.onSurface,
            semanticLabel: 'Símbolo de ROUTB',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                role.modeLabel,
                style: RoutbText.copy(12, color: const Color(0xB8FFFFFF)),
              ),
              Text(
                wave ? 'Hola, $userName 👋' : 'Hola, $userName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: RoutbText.headline(22, color: Colors.white),
              ),
            ],
          ),
        ),
        ThemeToggle(onDarkBackground: isDarkBackground),
        const SizedBox(width: 4),
        if (onLocationPrivacy != null) ...[
          IconButton(
            tooltip: 'Privacidad de ubicación',
            onPressed: onLocationPrivacy,
            constraints: const BoxConstraints.tightFor(width: 32, height: 36),
            padding: EdgeInsets.zero,
            icon: const Icon(
              Icons.location_on_outlined,
              size: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 4),
        ],
        HeroAction(label: 'Salir', icon: Icons.logout_rounded, onTap: onLogout),
      ],
    );
  }
}

/// `.out`: acción de texto con icono, blanca sobre el hero.
class HeroAction extends StatelessWidget {
  const HeroAction({
    required this.label,
    required this.icon,
    required this.onTap,
    super.key,
  });

  /// Texto de la acción.
  final String label;

  /// Icono de la acción.
  final IconData icon;

  /// Acción al pulsar.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final child = Opacity(
      opacity: 0.85,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(height: 2),
          Text(
            label,
            style: RoutbText.copy(11, color: Colors.white, weight: FontWeight.w700),
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(RoutbTheme.radiusControl),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: child,
          ),
        ),
      ),
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
    final foreground = onDarkBackground
        ? Colors.white
        : (isDark ? const Color(0xFFA79BFF) : const Color(0xFF6C5CFF));

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
