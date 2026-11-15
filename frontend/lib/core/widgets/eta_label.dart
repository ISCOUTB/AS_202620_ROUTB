import 'package:flutter/material.dart';

import '../theme/routb_palette.dart';
import '../theme/routb_text.dart';

/// Hora estimada de llegada a una parada, con el formato local del teléfono.
///
/// El backend guarda la ETA como instante con zona horaria; la etiqueta la
/// convierte a la hora local antes de mostrarla. Si no hay ETA no se construye
/// el widget, así que la pantalla no necesita comprobar el nulo dos veces.
class EtaLabel extends StatelessWidget {
  const EtaLabel({
    required this.eta,
    this.prefix = 'Recogida estimada',
    this.compact = false,
    super.key,
  });

  /// Instante calculado por el backend.
  final DateTime eta;

  /// Texto que antecede a la hora.
  final String prefix;

  /// `true` para la fila densa de las tarjetas.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final time = TimeOfDay.fromDateTime(eta.toLocal()).format(context);
    final style = RoutbText.copy(
      compact ? 11 : 12,
      color: palette.muted,
      weight: FontWeight.w600,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.schedule_rounded,
          size: compact ? 11 : 13,
          color: palette.muted,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            '$prefix $time',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }
}
