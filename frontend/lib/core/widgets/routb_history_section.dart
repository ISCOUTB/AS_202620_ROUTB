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
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 7),
                Text(
                  title,
                  style: RoutbText.copy(
                    15,
                    color: palette.ink,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: palette.line),
                  ),
                  child: Text(
                    '$count',
                    style: RoutbText.copy(
                      11,
                      color: palette.muted,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}
