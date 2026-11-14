import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/theme/routb_theme.dart';
import 'package:frontend/core/widgets/location_permission_dialog.dart';
import 'package:frontend/core/widgets/routb_permission_status.dart';

Widget _app(Widget child) => MaterialApp(
  theme: RoutbTheme.light(),
  home: Scaffold(body: child),
);

void main() {
  group('RoutbPermissionStatus', () {
    testWidgets('muestra el estado activo sin acción', (tester) async {
      await tester.pumpWidget(
        _app(
          const RoutbPermissionStatus(
            title: 'Ubicación',
            description: 'Para buscar direcciones.',
            icon: Icons.location_on_outlined,
            state: RoutbPermissionState.granted,
          ),
        ),
      );

      expect(find.text('Ubicación'), findsOneWidget);
      expect(find.text('Activo'), findsOneWidget);
      expect(find.text('Abrir ajustes'), findsNothing);
    });

    testWidgets('muestra el estado desactivado y abre ajustes', (tester) async {
      var opened = 0;
      await tester.pumpWidget(
        _app(
          RoutbPermissionStatus(
            title: 'Notificaciones',
            description: 'Para avisarte de cambios.',
            icon: Icons.notifications_none_rounded,
            state: RoutbPermissionState.denied,
            onOpenSettings: () => opened++,
          ),
        ),
      );

      expect(find.text('Desactivado'), findsOneWidget);
      await tester.tap(find.text('Abrir ajustes'));
      expect(opened, 1);
    });

    testWidgets('muestra carga mientras consulta el permiso', (tester) async {
      await tester.pumpWidget(
        _app(
          const RoutbPermissionStatus(
            title: 'Ubicación',
            description: 'Para buscar direcciones.',
            icon: Icons.location_on_outlined,
            state: RoutbPermissionState.loading,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Activo'), findsNothing);
      expect(find.text('Desactivado'), findsNothing);
    });
  });

  group('Aviso de ubicación denegada', () {
    testWidgets('explica el problema y ofrece abrir ajustes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showLocationPermissionDialog(context),
                child: const Text('Probar'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Probar'));
      await tester.pumpAndSettle();

      expect(find.text('Activa la ubicación'), findsOneWidget);
      expect(find.textContaining('conceder el permiso'), findsOneWidget);
      expect(find.text('Abrir ajustes'), findsOneWidget);

      await tester.tap(find.text('Ahora no'));
      await tester.pumpAndSettle();
      expect(find.text('Activa la ubicación'), findsNothing);
    });
  });
}
