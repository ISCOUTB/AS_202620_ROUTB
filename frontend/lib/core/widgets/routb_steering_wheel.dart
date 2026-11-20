import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Volante dibujado a mano.
///
/// Material Icons no incluye un glifo de volante; este widget lo traza con el
/// mismo lenguaje simple de los iconos de la app y acepta el color del tema.
/// Se usa en la tarjeta «Vehículo» para no repetir el icono del carro, que
/// queda en la ficha del vehículo registrado.
class RoutbSteeringWheelIcon extends StatelessWidget {
  const RoutbSteeringWheelIcon({
    required this.color,
    this.size = 16,
    super.key,
  });

  /// Color del aro, los radios y el centro.
  final Color color;

  /// Lado del icono en píxeles lógicos.
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _SteeringWheelPainter(color)),
    );
  }
}

class _SteeringWheelPainter extends CustomPainter {
  const _SteeringWheelPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final center = size.center(Offset.zero);
    // Material deja un margen interno en sus glifos; el volante lo imita para
    // no verse más grande que los demás iconos del encabezado.
    final stroke = side / 11;
    final radius = side * 0.42 - stroke / 2;

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    // Aro.
    canvas.drawCircle(center, radius, strokePaint);

    // Radios a las 9, las 3 y las 6, como un volante real.
    for (final angle in const <double>[0, math.pi, math.pi / 2]) {
      final end = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      canvas.drawLine(center, end, strokePaint);
    }

    // Centro.
    canvas.drawCircle(
      center,
      stroke * 1.3,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _SteeringWheelPainter oldDelegate) =>
      oldDelegate.color != color;
}
