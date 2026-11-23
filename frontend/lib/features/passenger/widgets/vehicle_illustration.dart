import 'package:flutter/material.dart';

import '../../../core/theme/routb_palette.dart';

/// Miniatura local compartida por los viajes del pasajero.
class VehicleIllustration extends StatelessWidget {
  const VehicleIllustration({required this.width, super.key});

  static const asset = 'assets/vehicles/car_generic.webp';
  final double width;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      image: true,
      label: 'Ilustración genérica de automóvil',
      child: Container(
        width: width,
        height: width * 0.72,
        padding: EdgeInsets.all(width * 0.06),
        decoration: BoxDecoration(
          color: palette.brandSurface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Image.asset(
          asset,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.directions_car_outlined,
            color: palette.onBrandSurface,
          ),
        ),
      ),
    );
  }
}
