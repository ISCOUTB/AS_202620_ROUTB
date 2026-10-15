import 'travel_time.dart';

/// Formatos compartidos para la fecha de un viaje.
abstract final class TripSchedule {
  static const List<String> _weekdays = <String>[
    'lun',
    'mar',
    'mié',
    'jue',
    'vie',
    'sáb',
    'dom',
  ];

  static const List<String> _months = <String>[
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  static DateTime dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// Fecha compacta para las tarjetas, identificando hoy y mañana claramente.
  static String dateLabel(DateTime date, {DateTime? now}) {
    final today = dateOnly(now ?? DateTime.now());
    final selected = dateOnly(date);
    final difference = selected.difference(today).inDays;
    final day = '${selected.day} ${_months[selected.month - 1]}';
    if (difference == 0) return 'Hoy, $day';
    if (difference == 1) return 'Mañana, $day';
    return '${_weekdays[selected.weekday - 1]}, $day';
  }

  /// Cierra [date] a la ventana permitida por la app: hoy o mañana.
  ///
  /// La API rechaza publicar o buscar viajes fuera de esa ventana (ADR 0016),
  /// así que una fecha heredada de una versión anterior se ajusta aquí.
  static DateTime clampToTripWindow(DateTime date, {DateTime? now}) {
    final today = dateOnly(now ?? DateTime.now());
    final tomorrow = today.add(const Duration(days: 1));
    final selected = dateOnly(date);
    if (selected.isBefore(today)) return today;
    if (selected.isAfter(tomorrow)) return tomorrow;
    return selected;
  }

  /// Próxima fecha en que la hora elegida todavía no haya pasado.
  static DateTime nextOccurrence(TravelTime time, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final today = dateOnly(current);
    final candidate = time.todayAt(current);
    return candidate.isAfter(current)
        ? today
        : today.add(const Duration(days: 1));
  }
}
