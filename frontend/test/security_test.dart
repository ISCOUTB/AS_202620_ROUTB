import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/core/models/user_role.dart';
import 'package:frontend/core/services/device_launcher.dart';
import 'package:frontend/core/theme/routb_theme.dart';
import 'package:frontend/features/safety/data/emergency_contacts_store.dart';
import 'package:frontend/features/safety/models/active_trip_info.dart';
import 'package:frontend/features/safety/screens/emergency_contacts_screen.dart';
import 'package:frontend/features/safety/screens/safety_info_screen.dart';
import 'package:frontend/features/safety/screens/security_screen.dart';
import 'package:frontend/features/safety/screens/support_screen.dart';

Widget _app(Widget child) =>
    MaterialApp(theme: RoutbTheme.light(), home: child);

Widget _tab(Widget child) => _app(Scaffold(body: SafeArea(child: child)));

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('el 123 pide confirmación y abre el marcador', (tester) async {
    final uris = <Uri>[];
    final launcher = DeviceLauncher(
      launchUri: (uri) async {
        uris.add(uri);
        return true;
      },
    );

    await tester.pumpWidget(
      _tab(
        SecurityScreen(
          role: UserRole.passenger,
          userName: 'Ana',
          launcher: launcher,
        ),
      ),
    );
    await _settle(tester);

    await tester.tap(find.text('Llamar al 123'));
    await tester.pumpAndSettle();
    expect(find.text('¿Llamar al 123?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Llamar'));
    await tester.pumpAndSettle();

    expect(uris, hasLength(1));
    expect(uris.single.scheme, 'tel');
    expect(uris.single.path, '123');
  });

  testWidgets('con viaje activo el mensaje de emergencia incluye la ruta', (
    tester,
  ) async {
    final uris = <Uri>[];
    final launcher = DeviceLauncher(
      launchUri: (uri) async {
        uris.add(uri);
        return true;
      },
    );
    const trip = ActiveTripInfo(
      origin: 'Manga',
      destination: 'UTB',
      departureLabel: '7:00 AM',
    );

    await tester.pumpWidget(
      _app(
        EmergencyContactsScreen(
          userName: 'Ana',
          activeTrip: trip,
          launcher: launcher,
          store: const EmergencyContactsStore(),
        ),
      ),
    );
    await _settle(tester);

    await tester.tap(find.text('Agregar contacto'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Mamá');
    await tester.enterText(find.byType(TextField).at(1), '3001234567');
    await tester.tap(find.text('Guardar contacto'));
    await tester.pumpAndSettle();

    expect(find.text('Mamá'), findsOneWidget);
    expect(find.text('3001234567'), findsOneWidget);

    await tester.tap(find.text('Mamá'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Avisar por WhatsApp'));
    await tester.pumpAndSettle();

    expect(uris, hasLength(1));
    expect(uris.single.host, 'wa.me');
    final message = uris.single.queryParameters['text'] ?? '';
    expect(message, contains('Manga'));
    expect(message, contains('UTB'));
    expect(message, contains('7:00 AM'));

    // Deja que el aviso de «Contacto guardado» termine antes de desmontar.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('los contactos se guardan y se pueden eliminar', (tester) async {
    final store = const EmergencyContactsStore();
    await tester.pumpWidget(
      _app(EmergencyContactsScreen(userName: 'Ana', store: store)),
    );
    await _settle(tester);

    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Agregar contacto'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'Contacto $i');
      await tester.enterText(find.byType(TextField).at(1), '300123456$i');
      await tester.tap(find.text('Guardar contacto'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Contacto 0'), findsOneWidget);
    expect(find.text('Contacto 1'), findsOneWidget);
    expect((await store.load()), hasLength(2));

    await tester.tap(find.byTooltip('Opciones de Contacto 0'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar contacto'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Eliminar'));
    await tester.pumpAndSettle();

    expect(find.text('Contacto 0'), findsNothing);
    expect(await store.load(), hasLength(1));

    // Deja que el aviso de «Contacto eliminado» termine antes de desmontar.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('la información de seguridad cambia por rol', (tester) async {
    await tester.pumpWidget(
      _app(const SafetyInfoScreen(role: UserRole.passenger)),
    );
    await _settle(tester);
    expect(find.text('Antes de subir'), findsOneWidget);
    expect(find.text('Antes de publicar'), findsNothing);

    await tester.pumpWidget(
      _app(const SafetyInfoScreen(role: UserRole.driver)),
    );
    await _settle(tester);
    expect(find.text('Antes de publicar'), findsOneWidget);
    expect(find.text('Antes de subir'), findsNothing);
  });

  testWidgets('Soporte muestra los dos canales y el mensaje preparado', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const SupportScreen(userName: 'Ana', role: UserRole.passenger)),
    );
    await _settle(tester);

    expect(find.text('Escribir por WhatsApp'), findsOneWidget);
    expect(find.text('Enviar un correo'), findsOneWidget);
    expect(find.textContaining('Ana (pasajero)'), findsOneWidget);
  });

  testWidgets('Seguridad cabe en un móvil estrecho', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _tab(const SecurityScreen(role: UserRole.passenger, userName: 'Ana')),
    );
    await _settle(tester);

    expect(find.text('Llamar al 123'), findsOneWidget);
    expect(find.text('Soporte'), findsOneWidget);
    expect(find.text('Contactos de emergencia'), findsOneWidget);
    expect(find.text('Información de seguridad'), findsOneWidget);
    // La última entrada queda por encima de la barra, sin scroll.
    expect(
      tester.getBottomRight(find.text('Información de seguridad')).dy,
      lessThan(568 - 84),
    );
    expect(tester.takeException(), isNull);
  });
}
