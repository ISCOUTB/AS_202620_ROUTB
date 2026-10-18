import 'package:flutter/material.dart';

import '../theme/routb_palette.dart';
import '../theme/routb_text.dart';

/// Pestaña de la barra inferior de ROUTB.
@immutable
class RoutbNavItem {
  const RoutbNavItem({required this.label, required this.icon, this.badge = 0});

  /// Texto bajo el icono.
  final String label;

  /// Icono de la pestaña.
  final IconData icon;

  /// Contador sobre el icono. Con 0 no se muestra.
  final int badge;
}

/// Barra inferior compartida por los dos modos.
///
/// La pestaña activa va sobre la superficie de marca y su icono en color de
/// marca. Pasajero y conductor usan esta misma barra para que los dos modos se
/// vean igual.
class RoutbNavBar extends StatelessWidget {
  const RoutbNavBar({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  /// Pestañas, en el orden en que se muestran.
  final List<RoutbNavItem> items;

  /// Índice de la pestaña activa.
  final int selectedIndex;

  /// Se llama con el índice de la pestaña pulsada.
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        border: Border(top: BorderSide(color: palette.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var index = 0; index < items.length; index++)
                _RoutbNavTab(
                  item: items[index],
                  selected: index == selectedIndex,
                  onTap: () => onSelected(index),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoutbNavTab extends StatelessWidget {
  const _RoutbNavTab({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final RoutbNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = selected ? palette.brand : palette.muted;
    final badge = item.badge;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: badge > 0 ? '${item.label}, $badge activos' : item.label,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? palette.brandSurface : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(item.icon, size: 20, color: color),
                      if (badge > 0)
                        Positioned(
                          right: -8,
                          top: -5,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: palette.mint,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: const BoxConstraints(minWidth: 15),
                            child: Text(
                              badge > 9 ? '9+' : '$badge',
                              textAlign: TextAlign.center,
                              style: RoutbText.copy(9, color: palette.onMint),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RoutbText.copy(
                        12,
                        color: color,
                        weight: selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
