import 'package:flutter/material.dart';

import '../theme/routb_palette.dart';
import '../theme/routb_text.dart';
import '../theme/routb_theme.dart';

/// Encabezado compacto de las pestañas que no son la principal de cada rol.
///
/// A diferencia de `HeroBar`, no muestra el saludo ni el modo: solo el título
/// de la sección, para que Historial, Seguridad y Perfil no repitan la
/// bienvenida. Mantiene el degradado del hero para que el cambio de pestaña no
/// se sienta como otra app.
class RoutbSectionHeader extends StatelessWidget {
  const RoutbSectionHeader({
    required this.title,
    this.subtitle,
    this.trailing,
    super.key,
  });

  /// Título de la sección.
  final String title;

  /// Texto corto bajo el título, si hace falta.
  final String? subtitle;

  /// Acción opcional a la derecha.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: palette.heroGradient,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(RoutbTheme.radiusSheet),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RoutbText.headline(22, color: palette.onBrand),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: RoutbText.copy(
                      12,
                      color: palette.heroMuted,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );
  }
}
