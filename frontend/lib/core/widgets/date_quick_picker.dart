import 'package:flutter/material.dart';

import '../models/trip_schedule.dart';
import 'routb_field.dart';

/// Selector de fecha con las dos opciones permitidas: hoy y mañana.
///
/// Reemplaza al calendario: la API rechaza publicar o buscar viajes fuera de
/// esa ventana (ADR 0016), así que la interfaz solo ofrece esas dos fechas.
class DateQuickPicker extends StatelessWidget {
  const DateQuickPicker({
    required this.value,
    required this.onChanged,
    this.now,
    super.key,
  });

  /// Fecha seleccionada; se compara solo por día.
  final DateTime value;

  /// Se notifica con el día elegido, siempre normalizado a medianoche.
  final ValueChanged<DateTime> onChanged;

  /// Reloj inyectable para las pruebas.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final today = TripSchedule.dateOnly(now ?? DateTime.now());
    final tomorrow = today.add(const Duration(days: 1));
    final selected = TripSchedule.clampToTripWindow(value, now: now);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        RoutbChip(
          label: 'Hoy',
          selected: selected == today,
          onTap: () => onChanged(today),
        ),
        RoutbChip(
          label: 'Mañana',
          selected: selected == tomorrow,
          onTap: () => onChanged(tomorrow),
        ),
      ],
    );
  }
}
