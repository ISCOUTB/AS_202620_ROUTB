import 'package:flutter/material.dart';

import '../theme/routb_palette.dart';
import '../theme/routb_text.dart';
import '../theme/routb_theme.dart';

/// Insignia con el modelo y la placa del vehículo del conductor.
///
/// Solo se pinta cuando la API entrega la ficha, es decir, para el pasajero con
/// cupo confirmado. El listado público nunca la incluye.
class RoutbVehicleBadge extends StatelessWidget {
  const RoutbVehicleBadge({required this.info, this.dense = false, super.key});

  /// Texto de la ficha, como «Chevrolet Spark · Gris (XYZ-123)».
  final String info;

  /// Versión compacta para tarjetas pequeñas.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Semantics(
      label: 'Vehículo: $info',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 8 : 10,
          vertical: dense ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: palette.brandSurface,
          borderRadius: BorderRadius.circular(RoutbTheme.radiusPill),
          border: Border.all(
            color: palette.brand.withValues(alpha: 0.18),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.directions_car_filled_rounded,
              size: dense ? 12 : 14,
              color: palette.onBrandSurface,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                info,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: RoutbText.copy(
                  dense ? 10.5 : 11.5,
                  color: palette.onBrandSurface,
                  weight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
