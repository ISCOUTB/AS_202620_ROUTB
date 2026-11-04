import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/routb_palette.dart';
import '../theme/routb_text.dart';

/// Pinta una línea discontinua horizontal o vertical.
class _DashesPainter extends CustomPainter {
  const _DashesPainter({required this.color, required this.horizontal});

  final Color color;
  final bool horizontal;

  static const double _dash = 6;
  static const double _gap = 4;
  static const double _strokeWidth = 2;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.butt;

    if (horizontal) {
      final y = size.height / 2;
      for (var x = 0.0; x < size.width; x += _dash + _gap) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + _dash, size.width), y),
          paint,
        );
      }
    } else {
      final x = 9.0;
      for (var y = 0.0; y < size.height; y += _dash + _gap) {
        canvas.drawLine(
          Offset(x, y),
          Offset(x, math.min(y + _dash, size.height)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DashesPainter old) =>
      old.color != color || old.horizontal != horizontal;
}

/// `.pf`: separador punteado entre el trayecto y los cupos de una tarjeta.
class DashedDivider extends StatelessWidget {
  const DashedDivider({this.color, super.key});

  /// Color de la línea.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SizedBox(
      height: 2,
      child: CustomPaint(
        painter: _DashesPainter(color: color ?? palette.line, horizontal: true),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// `.pth`: origen y destino alineados en los extremos de la tarjeta.
class TravelPath extends StatelessWidget {
  const TravelPath({
    required this.origin,
    required this.destination,
    super.key,
  });

  /// Punto de partida.
  final String origin;

  /// Punto de llegada.
  final String destination;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line.withValues(alpha: 0.75)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: palette.brand, width: 2),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        'Origen',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RoutbText.copy(
                          11,
                          color: palette.muted,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  origin,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RoutbText.headline(15, color: palette.ink),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: palette.brandSurface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: palette.brand,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        'Destino',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RoutbText.copy(
                          11,
                          color: palette.muted,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: palette.mint,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  destination,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: RoutbText.headline(15, color: palette.ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Una parada de la línea de tiempo de una ruta.
class TimelineStop extends StatelessWidget {
  const TimelineStop({
    required this.title,
    required this.subtitle,
    this.reached = false,
    super.key,
  });

  /// Nombre del lugar.
  final String title;

  /// Texto bajo el nombre: «Salida 7:00 AM» o «Llegada estimada 7:25 AM».
  final String subtitle;

  /// `true` cuando el punto ya se pinta en menta.
  final bool reached;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final activeColor = reached ? palette.mint : palette.brand;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 26,
          height: 20,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: activeColor.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: activeColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: RoutbText.headline(15, color: palette.ink),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: RoutbText.copy(12, color: palette.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// `.tl`: paradas unidas por una línea punteada vertical.
class DashedTimeline extends StatelessWidget {
  const DashedTimeline({required this.stops, super.key});

  /// Paradas, en orden.
  final List<TimelineStop> stops;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 10,
          bottom: 24,
          child: CustomPaint(
            painter: _DashesPainter(color: palette.line, horizontal: false),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < stops.length; index++) ...[
              if (index > 0) const SizedBox(height: 16),
              stops[index],
            ],
          ],
        ),
      ],
    );
  }
}
