import 'package:flutter/material.dart';

import '../theme/routb_palette.dart';
import '../theme/routb_text.dart';

/// Grupo del historial: encabezado con icono, color y contador, y sus tarjetas.
///
/// Lo comparten el historial del pasajero y el del conductor para que ambos
/// agrupen sus viajes con el mismo lenguaje visual.
class RoutbHistorySection extends StatelessWidget {
  const RoutbHistorySection({
    required this.title,
    required this.icon,
    required this.color,
    required this.count,
    required this.children,
    super.key,
  });

  /// Título del grupo, como «Completados» o «Canceladas».
  final String title;

  /// Icono que resume el grupo.
  final IconData icon;

  /// Color del icono, normalmente verde para completados y rojo para cancelados.
  final Color color;

  /// Número de elementos del grupo.
  final int count;

  /// Tarjetas del grupo.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: palette.ink, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: RoutbText.headline(21, color: palette.ink),
                    ),
                  ),
                ),
                Text(
                  '$count',
                  style: RoutbText.headline(20, color: palette.muted),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: color.withValues(alpha: .55),
                    width: 2,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Column(children: children),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
