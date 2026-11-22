import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/core/models/user_role.dart';
import 'package:frontend/core/network/api_exception.dart';
import 'package:frontend/core/services/device_launcher.dart';
import 'package:frontend/core/theme/routb_theme.dart';
import 'package:frontend/features/safety/data/emergency_contacts_store.dart';
import 'package:frontend/features/safety/data/support_repository.dart';
import 'package:frontend/features/safety/models/active_trip_info.dart';
import 'package:frontend/features/safety/screens/emergency_contacts_screen.dart';
import 'package:frontend/features/safety/screens/safety_info_screen.dart';
import 'package:frontend/features/safety/screens/security_screen.dart';
import 'package:frontend/features/safety/screens/support_screen.dart';
import 'package:frontend/features/safety/screens/support_report_screen.dart';

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

    final call = find.widgetWithText(FilledButton, 'Llamar al 123');
    expect(tester.getSize(call).height, greaterThanOrEqualTo(60));
    await tester.tap(call);
    await tester.pumpAndSettle();
    expect(find.text('¿Llamar al 123?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Llamar'));
    await tester.pumpAndSettle();

    expect(uris, hasLength(1));
    expect(uris.single.scheme, 'tel');
    expect(uris.single.path, '123');
  });

  testWidgets('los consejos de seguridad dependen del rol', (tester) async {
    await tester.pumpWidget(
      _tab(SecurityScreen(role: UserRole.driver, userName: 'Carlos')),
    );
    await _settle(tester);

    expect(find.text('Consejos para conductores'), findsOneWidget);
    expect(find.text('Recomendaciones para una ruta segura'), findsOneWidget);
    expect(find.text('Consejos para pasajeros'), findsNothing);

    await tester.pumpWidget(
      _tab(SecurityScreen(role: UserRole.passenger, userName: 'Ana')),
    );
    await _settle(tester);

    expect(find.text('Consejos para pasajeros'), findsOneWidget);
    expect(find.text('Viaja con tranquilidad y confianza'), findsOneWidget);
    expect(find.text('Consejos para conductores'), findsNothing);
    expect(tester.takeException(), isNull);
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
          store: const EmergencyContactsStore(1),
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
    final store = const EmergencyContactsStore(1);
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
    expect(await const EmergencyContactsStore(2).load(), isEmpty);

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
    expect(find.text('Consejos para pasajeros'), findsOneWidget);
    for (final (guide, detail) in [
      ('Antes del viaje', 'Antes de subir'),
      ('Después del viaje', 'Confirma tu llegada'),
      ('En caso de emergencia', 'Ponte a salvo primero'),
    ]) {
      await tester.tap(find.text(guide));
      await tester.pumpAndSettle();
      expect(find.text(detail), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
    expect(find.text('Antes de publicar'), findsNothing);

    await tester.pumpWidget(
      _app(const SafetyInfoScreen(role: UserRole.driver)),
    );
    await _settle(tester);
    expect(find.text('Consejos para conductores'), findsOneWidget);
    expect(find.text('Antes de publicar'), findsOneWidget);
    expect(find.text('Antes de subir'), findsNothing);
  });

  testWidgets('Soporte muestra reportes y preguntas frecuentes', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const SupportScreen()));
    await _settle(tester);

    expect(find.text('Reportar un problema'), findsOneWidget);
    expect(find.text('Contactar al equipo'), findsNothing);
    await tester.tap(find.text('Preguntas frecuentes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('¿Cuándo queda confirmado mi cupo?'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('hasta que el conductor la acepte'),
      findsOneWidget,
    );
  });

  testWidgets('el formulario valida, conserva el borrador y muestra el folio', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final first = Completer<int>();
    final reports = <SupportReport>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: RoutbTheme.dark(),
        home: SupportReportScreen(
          submit: (report) {
            reports.add(report);
            return reports.length == 1 ? first.future : Future.value(42);
          },
        ),
      ),
    );

    final send = find.text('Enviar reporte');
    Future<void> sendReport() async {
      await tester.ensureVisible(send);
      await tester.pumpAndSettle();
      await tester.tap(send);
      await tester.pump();
    }

    await sendReport();
    expect(find.text('Elige un tipo de problema.'), findsOneWidget);
    expect(find.text('Escribe al menos 10 caracteres.'), findsOneWidget);
    expect(reports, isEmpty);
    final category = find.text('Tipo de problema');
    await tester.ensureVisible(category);
    await tester.pumpAndSettle();
    await tester.tap(category);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Viaje').last);
    await tester.pumpAndSettle();
    const description = 'El punto de encuentro cambió.';
    await tester.enterText(find.byType(TextField), description);
    await sendReport();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    first.completeError(const ApiException('Conexión interrumpida.'));
    await tester.pumpAndSettle();
    expect(find.text('Conexión interrumpida.'), findsOneWidget);
    expect(find.text(description), findsOneWidget);
    await sendReport();
    await tester.pumpAndSettle();
    expect(reports, hasLength(2));
    expect(reports.last.submissionId, reports.first.submissionId);
    expect(find.text('Reporte registrado. Folio #42.'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
    expect(find.text('Contactos de emergencia'), findsOneWidget);
    expect(find.text('Consejos para pasajeros'), findsOneWidget);
    expect(find.text('Antes del viaje').hitTestable(), findsOneWidget);
    expect(
      tester.getBottomRight(find.text('Consejos para pasajeros')).dy,
      lessThan(568 - 84),
    );
    await tester.tap(find.text('Antes del viaje'));
    await tester.pumpAndSettle();
    expect(find.text('Confirma la ruta y el encuentro'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    final faq = find.text('Preguntas frecuentes');
    await tester.scrollUntilVisible(
      faq,
      170,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    expect(find.text('Soporte'), findsOneWidget);
    expect(find.text('Reportar un problema'), findsOneWidget);
    expect(find.text('Contactar al equipo'), findsNothing);
    await tester.tap(faq.hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('¿Cuándo queda confirmado mi cupo?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
