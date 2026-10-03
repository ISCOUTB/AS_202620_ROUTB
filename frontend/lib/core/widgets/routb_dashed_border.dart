import 'package:flutter/material.dart';

import '../theme/routb_palette.dart';

/// Contenedor con borde discontinuo redondeado.
///
/// Flutter no tiene bordes `dashed` en la caja, así que el trazo se pinta a mano.
/// El diseño lo usa en los asientos libres del conductor.
class DashedBorderBox extends StatelessWidget {
  const DashedBorderBox({
    required this.child,
    this.color,
    this.strokeWidth = 1.5,
    this.dash = 5,
    this.gap = 4,
    this.borderRadius = const BorderRadius.all(Radius.circular(11)),
    this.fillColor,
    this.gradient,
    super.key,
  });

  /// Contenido del contenedor.
  final Widget child;

  /// Color del trazo.
  final Color? color;

  /// Grosor del trazo.
  final double strokeWidth;

  /// Longitud de cada tramo.
  final double dash;

  /// Separación entre tramos.
  final double gap;

  /// Radio de las esquinas.
  final BorderRadius borderRadius;

  /// Relleno sólido; tiene prioridad sobre [gradient].
  final Color? fillColor;

  /// Relleno con degradado.
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final stroke = color ?? context.palette.line;

    return CustomPaint(
      painter: _DashedRoundedRectPainter(
        color: stroke,
        strokeWidth: strokeWidth,
        dash: dash,
        gap: gap,
        borderRadius: borderRadius,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fillColor,
          gradient: gradient,
          borderRadius: borderRadius,
        ),
        child: child,
      ),
    );
  }
}

class _DashedRoundedRectPainter extends CustomPainter {
  const _DashedRoundedRectPainter({
    required this.color,
    required this.strokeWidth,
    required this.dash,
    required this.gap,
    required this.borderRadius,
  });

  final Color color;
  final double strokeWidth;
  final double dash;
  final double gap;
  final BorderRadius borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          borderRadius.topLeft,
        ),
      );

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRoundedRectPainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.dash != dash ||
      old.gap != gap ||
      old.borderRadius != borderRadius;
}