import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/trip.dart';
import 'package:frontend/core/theme/routb_theme.dart';
import 'package:frontend/features/driver/screens/publish_route_screen.dart';
import 'package:frontend/features/passenger/screens/reserve_seats_screen.dart';

void main() {
  for (final driver in [true, false]) {
    final title = driver ? 'Nueva ruta' : 'Solicitar cupo hacia la UTB';
    testWidgets('$title se abre como página y permite volver', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: RoutbTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  if (driver) {
                    openPublishRouteScreen(
                      context: context,
                      driverName: 'Ana',
                      driverInitials: 'A',
                    );
                  } else {
                    openReserveSeatsScreen(
                      context: context,
                      trip: Trip.fromJson({
                        'id': 1,
                        'origin': 'Manga',
                        'destination': 'UTB',
                        'total_seats': 3,
                        'available_seats': 2,
                        'departure_time': '7:00 AM',
                        'driver_name': 'Ana',
                      }),
                    );
                  }
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(ModalRoute.of(tester.element(find.text(title))), isA<PageRoute>());
      expect(find.byType(DraggableScrollableSheet), findsNothing);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Abrir'), findsOneWidget);
    });
  }
}
