import 'package:flutter/foundation.dart';

/// Hora del día en formato de 12 horas, como la que guarda la API.
///
/// El backend almacena `departure_time` como **texto libre** (`"7:00 AM"`), así
/// que esta clase nunca lanza: [tryParse] devuelve `null` cuando el valor no es
/// interpretable y la interfaz recurre al texto original en lugar de romperse.
///
/// ```dart
/// final hora = TravelTime.tryParse('7:00 AM');   // 7:00 AM
/// hora!.label;                                   // '7:00 AM'
/// (hora + const Zone('Manga').minutes).label;    // 7:22 AM
/// ```
@immutable
class TravelTime implements Comparable<TravelTime> {
  /// Minutos desde medianoche, en el rango `0..1439`.
  const TravelTime(this.minutes)
      : assert(minutes >= 0 && minutes < 1440, 'La hora debe estar en 0..1439');

  /// Construye una hora a partir de hora y minuto.
  const TravelTime.fromClock(int hour, int minute)
      : minutes = hour * 60 + minute,
        assert(hour >= 0 && hour < 24),
        assert(minute >= 0 && minute < 60);

  /// Minutos desde medianoche.
  final int minutes;

  static final RegExp _pattern = RegExp(
    r'^\s*(\d{1,2})(?::(\d{2}))?\s*([aApP])\.?[mM]\.?\s*$',
  );

  static final RegExp _clockOnly = RegExp(r'^\s*(\d{1,2})(?::(\d{2}))?\s*$');

  /// Interpreta el texto de la API. Acepta `7:00 AM`, `7:00am`, `7 AM` y
  /// `7:00` (sin indicador, se asume AM).
  static TravelTime? tryParse(String? raw) {
    if (raw == null) return null;
    final text = raw.trim();
    if (text.isEmpty) return null;

    final withMeridiem = _pattern.firstMatch(text);
    if (withMeridiem != null) {
      var hour = int.parse(withMeridiem.group(1)!);
      final minute = int.parse(withMeridiem.group(2) ?? '0');
      final isPm = withMeridiem.group(3)!.toLowerCase() == 'p';
      if (hour < 1 || hour > 12 || minute > 59) return null;
      if (isPm && hour != 12) hour += 12;
      if (!isPm && hour == 12) hour = 0;
      return TravelTime.fromClock(hour, minute);
    }

    final clockOnly = _clockOnly.firstMatch(text);
    if (clockOnly != null) {
      final hour = int.parse(clockOnly.group(1)!);
      final minute = int.parse(clockOnly.group(2) ?? '0');
      if (hour > 23 || minute > 59) return null;
      return TravelTime.fromClock(hour, minute);
    }

    return null;
  }

  /// Hora del día en `0..23`.
  int get hour => minutes ~/ 60;

  /// Minuto de la hora.
  int get minute => minutes % 60;

  /// `AM` o `PM`.
  String get meridiem => hour < 12 ? 'AM' : 'PM';

  /// Solo la hora: `7:00`.
  String get clockLabel =>
      '${hour % 12 == 0 ? 12 : hour % 12}:${minute.toString().padLeft(2, '0')}';

  /// Hora completa: `7:00 AM`.
  String get label => '$clockLabel $meridiem';

  /// Devuelve [departureTime] con la hora actual. Los días no importan.
  DateTime todayAt([DateTime? now]) {
    final reference = now ?? DateTime.now();
    return DateTime(
      reference.year,
      reference.month,
      reference.day,
      hour,
      minute,
    );
  }

  /// Cuántos minutos faltan desde [now] hasta esta hora, contando hacia atrás
  /// si la hora ya pasó (por ejemplo, las 23:00 son -120 desde las 01:00).
  int minutesUntil(DateTime now) => minutes - (now.hour * 60 + now.minute);

  /// `true` si la hora cae dentro de [window] a partir de [now].
  ///
  /// Se usa para marcar los viajes que salen en breve.
  bool isWithin(
    DateTime now, {
    Duration window = const Duration(minutes: 90),
  }) {
    final delta = minutesUntil(now);
    return delta >= 0 && delta <= window.inMinutes;
  }

  /// Devuelve la hora desplazada [amount] minutos, envolviendo el día.
  TravelTime shifted(int amount) => TravelTime((minutes + amount) % 1440);

  @override
  int compareTo(TravelTime other) => minutes.compareTo(other.minutes);

  @override
  bool operator ==(Object other) =>
      other is TravelTime && other.minutes == minutes;

  @override
  int get hashCode => minutes.hashCode;

  @override
  String toString() => label;
}