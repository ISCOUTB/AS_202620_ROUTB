import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/trip_schedule.dart';
import 'package:frontend/core/theme/routb_theme.dart';
import 'package:frontend/core/widgets/date_quick_picker.dart';
import 'package:frontend/core/widgets/routb_field.dart';

void main() {
  final DateTime now = DateTime(2026, 10, 15, 9, 30);
  final DateTime today = TripSchedule.dateOnly(now);
  final DateTime tomorrow = today.add(const Duration(days: 1));

  Future<void> pumpPicker(
    WidgetTester tester, {
    required DateTime value,
    required ValueChanged<DateTime> onChanged,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: RoutbTheme.light(),
        home: Scaffold(
          body: DateQuickPicker(value: value, onChanged: onChanged, now: now),
        ),
      ),
    );
  }

  RoutbChip chipFor(WidgetTester tester, String label) {
    return tester.widget<RoutbChip>(
      find.ancestor(of: find.text(label), matching: find.byType(RoutbChip)),
    );
  }

  group('DateQuickPicker', () {
    testWidgets('solo ofrece Hoy y Mañana y notifica el día elegido', (
      tester,
    ) async {
      DateTime? picked;
      await pumpPicker(
        tester,
        value: today,
        onChanged: (date) => picked = date,
      );

      expect(find.text('Hoy'), findsOneWidget);
      expect(find.text('Mañana'), findsOneWidget);
      expect(chipFor(tester, 'Hoy').selected, isTrue);
      expect(chipFor(tester, 'Mañana').selected, isFalse);

      await tester.tap(find.text('Mañana'));
      expect(picked, tomorrow);

      await tester.tap(find.text('Hoy'));
      expect(picked, today);
    });

    testWidgets('marca Mañana cuando ese es el valor recibido', (tester) async {
      await pumpPicker(tester, value: tomorrow, onChanged: (_) {});

      expect(chipFor(tester, 'Hoy').selected, isFalse);
      expect(chipFor(tester, 'Mañana').selected, isTrue);
    });

    testWidgets('una fecha lejana se muestra como Mañana', (tester) async {
      await pumpPicker(
        tester,
        value: today.add(const Duration(days: 20)),
        onChanged: (_) {},
      );

      expect(chipFor(tester, 'Mañana').selected, isTrue);
    });
  });

  group('TripSchedule.clampToTripWindow', () {
    test('una fecha pasada se convierte en hoy', () {
      expect(
        TripSchedule.clampToTripWindow(
          today.subtract(const Duration(days: 3)),
          now: now,
        ),
        today,
      );
    });

    test('una fecha lejana se convierte en mañana', () {
      expect(
        TripSchedule.clampToTripWindow(
          today.add(const Duration(days: 10)),
          now: now,
        ),
        tomorrow,
      );
    });

    test('hoy y mañana se conservan sin cambios', () {
      expect(TripSchedule.clampToTripWindow(today, now: now), today);
      expect(TripSchedule.clampToTripWindow(tomorrow, now: now), tomorrow);
    });
  });
}
