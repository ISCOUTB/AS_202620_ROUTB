import 'package:flutter/material.dart';

import '../theme/routb_motion.dart';
import '../theme/routb_palette.dart';
import '../theme/routb_text.dart';
import 'routb_logo.dart';

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
/// Tiene cuatro pestañas y una acción central que no es una pestaña: el botón
/// circular con la marca abre el viaje activo, o su estado vacío cuando no hay
/// ninguno. La pestaña activa se pinta sobre la superficie de marca y su icono
/// en color de marca; el botón central se queda siempre destacado.
class RoutbNavBar extends StatelessWidget {
  const RoutbNavBar({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    required this.onCenterTap,
    this.centerActive = false,
    super.key,
  }) : assert(items.length == 4, 'La barra tiene cuatro pestañas y un centro');

  /// Pestañas, en el orden en que se muestran a los lados del botón central.
  final List<RoutbNavItem> items;

  /// Índice de la pestaña activa, de 0 a 3.
  final int selectedIndex;

  /// Se llama con el índice de la pestaña pulsada.
  final ValueChanged<int> onSelected;

  /// Se llama al pulsar el botón central.
  final VoidCallback onCenterTap;

  /// `true` cuando hay un viaje activo; dibuja el indicador del centro.
  final bool centerActive;

  /// Alto de la barra sin contar el área segura inferior.
  static const double _barHeight = 84;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SizedBox(
      height: _barHeight + bottomInset,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // La mitad superior de la barra queda transparente para que el botón
          // central sobresalga sin montarse sobre el contenido.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 70 + bottomInset,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: palette.card,
                border: Border(
                  top: BorderSide(color: palette.line.withValues(alpha: 0.85)),
                ),
                boxShadow: palette.cardShadow,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomInset,
            height: 70,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  Expanded(
                    child: _RoutbNavTab(
                      item: items[0],
                      selected: selectedIndex == 0,
                      onTap: () => onSelected(0),
                    ),
                  ),
                  Expanded(
                    child: _RoutbNavTab(
                      item: items[1],
                      selected: selectedIndex == 1,
                      onTap: () => onSelected(1),
                    ),
                  ),
                  const SizedBox(width: 60),
                  Expanded(
                    child: _RoutbNavTab(
                      item: items[2],
                      selected: selectedIndex == 2,
                      onTap: () => onSelected(2),
                    ),
                  ),
                  Expanded(
                    child: _RoutbNavTab(
                      item: items[3],
                      selected: selectedIndex == 3,
                      onTap: () => onSelected(3),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: _CenterAction(active: centerActive, onTap: onCenterTap),
            ),
          ),
        ],
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
    final color = selected ? palette.onBrandSurface : palette.muted;
    final badge = item.badge;

    return Semantics(
      button: true,
      selected: selected,
      label: badge > 0 ? '${item.label}, $badge activos' : item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Center(
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: RoutbMotion.standard,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            decoration: BoxDecoration(
              color: selected ? palette.brandSurface : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: selected
                  ? Border.all(
                      color: palette.brand.withValues(alpha: 0.28),
                      width: 1,
                    )
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(item.icon, size: 20, color: color),
                    if (badge > 0)
                      Positioned(
                        right: -9,
                        top: -6,
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
                            style: RoutbText.copy(
                              9,
                              color: palette.onMint,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: RoutbText.copy(
                    9.5,
                    color: color,
                    weight: selected ? FontWeight.w700 : FontWeight.w500,
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

/// Botón central con la marca. No lleva etiqueta visible: el lector de
/// pantalla anuncia si hay viaje activo y qué abre.
class _CenterAction extends StatelessWidget {
  const _CenterAction({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Semantics(
      button: true,
      label: active ? 'Abrir viaje activo' : 'Ver viaje activo',
      child: SizedBox(
        key: const Key('routb-center-action'),
        width: 58,
        height: 58,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: palette.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: palette.raisedShadow,
                  border: Border.all(
                    color: palette.card.withValues(alpha: 0.9),
                    width: 2,
                  ),
                ),
                child: InkWell(
                  onTap: onTap,
                  customBorder: const CircleBorder(),
                  child: const Center(
                    child: RoutbLogo(
                      variant: RoutbLogoVariant.onHero,
                      width: 30,
                      semanticLabel: 'Viaje activo',
                    ),
                  ),
                ),
              ),
            ),
            if (active)
              Positioned(
                right: 1,
                top: 1,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: palette.mint,
                    shape: BoxShape.circle,
                    border: Border.all(color: palette.card, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
