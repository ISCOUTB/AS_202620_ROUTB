import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/routb_palette.dart';
import '../theme/routb_text.dart';
import '../theme/routb_theme.dart';

/// `.av`: círculo con iniciales y degradado estable a partir del nombre.
///
/// El degradado sale del hash del texto, así cada persona mantiene su color sin
/// que el backend tenga que servir una imagen.
///
/// ```dart
/// const InitialsAvatar(name: 'Enzo Fernández', size: 42)
/// ```
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    required this.name,
    required this.initials,
    this.size = 42,
    super.key,
  });

  /// Nombre completo, del que se deriva el degradado.
  final String name;

  /// Iniciales ya calculadas.
  final String initials;

  /// Lado del avatar.
  final double size;

  @override
  Widget build(BuildContext context) {
    final seed = name.trim().isEmpty ? '?' : name;
    final hue = seed.hashCode.abs() % 360;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HSLColor.fromAHSL(1, hue.toDouble(), 0.85, 0.62).toColor(),
            HSLColor.fromAHSL(1, ((hue + 60) % 360).toDouble(), 0.85, 0.58)
                .toColor(),
          ],
        ),
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      child: Text(
        initials,
        style: RoutbText.headline(
          size * 0.34,
          color: Colors.white,
          height: 1,
        ),
      ),
    );
  }
}

/// `.dots`: los cuatro puntos que representan los cupos de un viaje.
///
/// Los libres van en menta y los ocupados en el color de línea, igual que en el
/// diseño. El número real de cupos del viaje manda sobre el ancho, para que un
/// viaje de 2 cupos no dibuje cuatro.
class SeatDots extends StatelessWidget {
  const SeatDots({
    required this.total,
    required this.available,
    this.size = const Size(10, 15),
    super.key,
  });

  /// Cupos que ofrece el viaje.
  final int total;

  /// Cupos libres.
  final int available;

  /// Tamaño de cada punto.
  final Size size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final slots = math.max(total, 1);
    final free = available.clamp(0, slots);

    return Semantics(
      label: '$free de $slots cupos libres',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < slots; index++)
            Container(
              width: size.width,
              height: size.height,
              margin: EdgeInsets.only(right: index == slots - 1 ? 0 : 4),
              decoration: BoxDecoration(
                color: index < free ? palette.mint : palette.line,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(5),
                  bottom: Radius.circular(2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// `.car`: rejilla de cupos del conductor, con la plaza del conductor fija.
///
/// Sirve para elegir cuántos cupos se ofrecen al publicar una ruta y para ver
/// el estado de cada plaza en el detalle de ruta.
class SeatSlots extends StatelessWidget {
  const SeatSlots({
    required this.selected,
    required this.onChanged,
    this.maxSeats = 4,
    this.locked = false,
    this.occupiedBy,
    super.key,
  });

  /// Número de cupos ofrecidos.
  final int selected;

  /// Se dispara al cambiar el número de cupos.
  final ValueChanged<int>? onChanged;

  /// Máximo de cupos.
  final int maxSeats;

  /// `true` impide cambiar los cupos, para cuando solo se muestran.
  final bool locked;

  /// Nombre de quien ocupa cada plaza, indexado desde cero.
  final List<String>? occupiedBy;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final names = occupiedBy ?? const <String>[];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(44),
          bottom: Radius.circular(30),
        ),
        border: Border.all(color: palette.line, width: 2),
      ),
      child: Column(
        children: [
          // `.car::before`: salpicadero.
          Container(
            width: 96,
            height: 6,
            decoration: BoxDecoration(
              color: palette.line,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 18),
          // Las plazas se reparten el ancho disponible: fijarlas en 46 px hacia
          // que en un teléfono de 360 px el `Row` se desborde. El ancho lo
          // decide el `LayoutBuilder`, nunca una constante.
          LayoutBuilder(
            builder: (context, constraints) {
              final slots = maxSeats + 1;
              final available = constraints.maxWidth;
              final gap = 6.0;
              final size = math.min(
                46.0,
                math.max(0.0, (available - gap * (slots - 1)) / slots),
              );

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Plaza del conductor.
                  _SeatSlot(
                    size: size,
                    filled: true,
                    isDriver: true,
                    child: Icon(
                      Icons.directions_car_filled_rounded,
                      size: size * 0.48,
                      color: palette.card,
                    ),
                  ),
                  for (var seat = 1; seat <= maxSeats; seat++)
                    _SeatSlot(
                      size: size,
                      filled: seat <= selected,
                      onTap: locked || onChanged == null
                          ? null
                          : () => onChanged!(seat),
                      semanticLabel: '$seat ${seat == 1 ? 'cupo' : 'cupos'}',
                      child: names.length >= seat
                          ? Text(
                              _shortName(names[seat - 1]),
                              style: RoutbText.headline(
                                math.min(13.0, size * 0.28),
                                color: palette.onMint,
                                height: 1,
                              ),
                            )
                          : null,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// «Sebastián Ríos» → «SR», para que quepa en la plaza.
  static String _shortName(String name) {
    final words = name.trim().split(RegExp(r'\s+'))
      ..removeWhere((word) => word.isEmpty);
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      final word = words.first;
      return word.substring(0, math.min(2, word.length)).toUpperCase();
    }
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }
}

class _SeatSlot extends StatelessWidget {
  const _SeatSlot({
    required this.size,
    required this.filled,
    this.onTap,
    this.isDriver = false,
    this.semanticLabel,
    this.child,
  });

  final double size;
  final bool filled;
  final VoidCallback? onTap;
  final bool isDriver;
  final String? semanticLabel;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: _decorationFor(context),
      child: child,
    );

    if (onTap == null) {
      return Semantics(label: semanticLabel, child: content);
    }

    return Semantics(
      button: true,
      selected: filled,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(size * 0.33),
          child: content,
        ),
      ),
    );
  }

  /// Relleno de la plaza: el conductor va en tinta, un cupo ocupado en menta y
  /// uno libre en superficie con borde punteado.
  BoxDecoration _decorationFor(BuildContext context) {
    final palette = context.palette;

    return BoxDecoration(
      color: isDriver
          ? palette.ink
          : filled
              ? null
              : palette.surface,
      gradient: !isDriver && filled ? palette.mintGradient : null,
      borderRadius: BorderRadius.circular(size * 0.33),
      border: isDriver || filled
          ? null
          : Border.all(color: palette.line, width: 1.5),
    );
  }
}

/// `.em`: mensaje cuando una lista no tiene nada que mostrar.
class RoutbEmptyState extends StatelessWidget {
  const RoutbEmptyState({
    required this.message,
    this.icon,
    this.action,
    super.key,
  });

  /// Texto centrado.
  final String message;

  /// Icono opcional sobre el mensaje.
  final IconData? icon;

  /// Acción opcional, como «Reintentar».
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 28, color: palette.muted),
            const SizedBox(height: 12),
          ],
          Text(
            message,
            textAlign: TextAlign.center,
            style: RoutbText.copy(13, color: palette.muted, height: 1.5),
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );
  }
}

/// Marcador de posición de carga, con el mismo criterio de ancho que el diseño.
class RoutbSkeleton extends StatefulWidget {
  const RoutbSkeleton({
    required this.height,
    this.width,
    this.radius = RoutbTheme.radiusCard,
    super.key,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  State<RoutbSkeleton> createState() => _RoutbSkeletonState();
}

class _RoutbSkeletonState extends State<RoutbSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  bool _shimmers = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _shimmers = !MediaQuery.disableAnimationsOf(context);
    if (_shimmers) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final wave = math.sin(_controller.value * math.pi).abs();
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(
              palette.surface,
              palette.line,
              0.25 + wave * 0.45,
            ),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}