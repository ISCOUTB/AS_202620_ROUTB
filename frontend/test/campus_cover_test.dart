import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/widgets/routb_campus_cover.dart';

void main() {
  testWidgets(
    'rota cada ocho segundos, pausa en segundo plano y respeta movimiento reducido',
    (tester) async {
      Widget cover(bool reduced) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: const RoutbCampusCover(child: Text('Seguridad')),
        ),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(cover(false));
      Finder scene(int index) => find.byKey(ValueKey(index));
      expect(scene(0), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
      await tester.pump(const Duration(seconds: 1));
      expect(scene(1), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 16));
      expect(scene(1), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      for (final index in [2, 3, 4, 0]) {
        await tester.pump(const Duration(seconds: 8));
        await tester.pump(const Duration(milliseconds: 610));
        expect(scene(index), findsOneWidget);
      }
      await tester.pumpWidget(cover(true));
      await tester.pump(const Duration(seconds: 9));
      expect(scene(0), findsOneWidget);
      await tester.drag(find.byType(RoutbCampusCover), const Offset(-160, 0));
      await tester.pumpAndSettle();
      expect(scene(1), findsOneWidget);
    },
  );
}
