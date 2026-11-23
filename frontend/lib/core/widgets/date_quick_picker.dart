import 'package:flutter/material.dart';

import '../models/trip_schedule.dart';
import '../theme/routb_palette.dart';
import '../theme/routb_text.dart';
import 'routb_field.dart';

/// Selector de fecha con las dos opciones permitidas: hoy y mañana.
///
/// Reemplaza al calendario: la API rechaza publicar o buscar viajes fuera de
/// esa ventana (ADR 0016), así que la interfaz solo ofrece esas dos fechas.
class DateQuickPicker extends StatelessWidget {
  const DateQuickPicker({
    required this.value,
    required this.onChanged,
    this.alignment = WrapAlignment.start,
    this.now,
    this.passengerStyle = false,
    super.key,
  });

  /// Fecha seleccionada; se compara solo por día.
  final DateTime value;

  /// Se notifica con el día elegido, siempre normalizado a medianoche.
  final ValueChanged<DateTime> onChanged;

  /// Alineación horizontal de las opciones.
  final WrapAlignment alignment;

  /// Reloj inyectable para las pruebas.
  final DateTime? now;

  /// Presentación de la búsqueda del pasajero.
  final bool passengerStyle;

  @override
  Widget build(BuildContext context) {
    final today = TripSchedule.dateOnly(now ?? DateTime.now());
    final tomorrow = today.add(const Duration(days: 1));
    final selected = TripSchedule.clampToTripWindow(value, now: now);

    final days = Wrap(
      alignment: alignment,
      spacing: passengerStyle ? 4 : 8,
      runSpacing: 8,
      children: <Widget>[
        for (final (day, label) in [(today, 'Hoy'), (tomorrow, 'Mañana')])
          if (passengerStyle)
            _DayPill(
              label: label,
              selected: selected == day,
              onTap: () => onChanged(day),
            )
          else
            RoutbChip(
              label: label,
              selected: selected == day,
              onTap: () => onChanged(day),
            ),
      ],
    );
    if (!passengerStyle) return days;
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.line),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Padding(padding: const EdgeInsets.all(3), child: days),
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final foreground = selected ? palette.onBrand : palette.ink;
    final radius = BorderRadius.circular(30);
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 48, minWidth: 110),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? palette.brand : palette.surface,
            borderRadius: radius,

            boxShadow: selected
                ? [
                    BoxShadow(
                      color: palette.brand.withValues(alpha: 0.20),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? Icons.check_rounded : Icons.calendar_today_outlined,
                color: foreground,
                size: 16,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: RoutbText.copy(
                    14,
                    color: foreground,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
