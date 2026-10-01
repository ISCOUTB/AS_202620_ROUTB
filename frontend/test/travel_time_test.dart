import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/models/travel_time.dart';

void main() {
  group('TravelTime.tryParse', () {
    test('interpreta los formatos que puede devolver la API', () {
      expect(TravelTime.tryParse('7:00 AM')?.label, '7:00 AM');
      expect(TravelTime.tryParse('7:00am')?.label, '7:00 AM');
      expect(TravelTime.tryParse('7:00 am')?.label, '7:00 AM');
      expect(TravelTime.tryParse('12:30 PM')?.label, '12:30 PM');
      expect(TravelTime.tryParse('12:00 AM')?.label, '12:00 AM');
      expect(TravelTime.tryParse('9:05 pm')?.label, '9:05 PM');
      expect(TravelTime.tryParse('7:00')?.label, '7:00 AM');
      expect(TravelTime.tryParse('  7:00 AM  ')?.minutes, 420);
      expect(TravelTime.tryParse('11:59 PM')?.minutes, 1439);
    });

    test('devuelve null en lugar de fallar con texto inválido', () {
      // `departure_time` es texto libre en la base de datos, así que un valor
      // raro no puede dejar la pantalla en blanco.
      expect(TravelTime.tryParse(null), isNull);
      expect(TravelTime.tryParse(''), isNull);
      expect(TravelTime.tryParse('   '), isNull);
      expect(TravelTime.tryParse('mañana'), isNull);
      expect(TravelTime.tryParse('99:99'), isNull);
      expect(TravelTime.tryParse('25:00'), isNull);
      expect(TravelTime.tryParse('7:00 XM'), isNull);
      expect(TravelTime.tryParse('13:00 PM'), isNull);
    });
  });

  group('TravelTime', () {
    test('separa la hora del indicador', () {
      const morning = TravelTime.fromClock(7, 5);
      expect(morning.clockLabel, '7:05');
      expect(morning.meridiem, 'AM');

      const noon = TravelTime.fromClock(12, 0);
      expect(noon.clockLabel, '12:00');

      const afternoon = TravelTime.fromClock(17, 30);
      expect(afternoon.clockLabel, '5:30');
      expect(afternoon.meridiem, 'PM');

      const midnight = TravelTime.fromClock(0, 0);
      expect(midnight.clockLabel, '12:00');
      expect(midnight.meridiem, 'AM');
    });

    test('desplaza la hora envolviendo el día', () {
      expect(const TravelTime.fromClock(7, 0).shifted(15).label, '7:15 AM');
      expect(const TravelTime.fromClock(7, 0).shifted(-15).label, '6:45 AM');
      expect(const TravelTime.fromClock(23, 50).shifted(20).label, '12:10 AM');
      expect(const TravelTime.fromClock(0, 10).shifted(-20).label, '11:50 PM');
    });

    test('cuenta los minutos que faltan hasta la hora', () {
      final now = DateTime(2026, 10, 1, 6, 30);
      expect(const TravelTime.fromClock(7, 0).minutesUntil(now), 30);
      expect(const TravelTime.fromClock(6, 0).minutesUntil(now), -30);
    });

    test('detecta las salidas próximas', () {
      final now = DateTime(2026, 10, 1, 6, 30);

      // Todo lo que salga dentro de los próximos 90 minutos cuenta.
      expect(const TravelTime.fromClock(7, 0).isWithin(now), isTrue);
      expect(const TravelTime.fromClock(6, 45).isWithin(now), isTrue);
      // Pasado algo más de hora y media: queda lejos.
      expect(const TravelTime.fromClock(8, 1).isWithin(now), isFalse);
      // Ya salió: deja de ser una salida próxima.
      expect(const TravelTime.fromClock(6, 15).isWithin(now), isFalse);
      // Con una ventana de cero solo cuenta la hora exacta.
      expect(
        const TravelTime.fromClock(6, 30).isWithin(now, window: Duration.zero),
        isTrue,
      );
      expect(
        const TravelTime.fromClock(7, 0).isWithin(now, window: Duration.zero),
        isFalse,
      );
    });

    test('se compara por valor', () {
      expect(const TravelTime.fromClock(7, 0), const TravelTime(420));
      expect(const TravelTime(420).hashCode, const TravelTime(420).hashCode);
      expect(const TravelTime(420).toString(), '7:00 AM');
    });
  });
}