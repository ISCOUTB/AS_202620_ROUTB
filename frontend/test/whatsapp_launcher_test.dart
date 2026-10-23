import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/services/whatsapp_launcher.dart';
import 'package:frontend/core/theme/routb_theme.dart';

Widget _app(Widget child) => MaterialApp(
  theme: RoutbTheme.light(),
  home: Scaffold(body: child),
);

void main() {
  group('WhatsAppLauncher', () {
    test(
      'normaliza números de celular colombianos de 10 dígitos a formato con 57',
      () {
        expect(WhatsAppLauncher.normalizePhone('3015550002'), '573015550002');
        expect(
          WhatsAppLauncher.normalizePhone('+57 301 555 0002'),
          '573015550002',
        );
        expect(WhatsAppLauncher.normalizePhone('301-555-0002'), '573015550002');
        expect(WhatsAppLauncher.normalizePhone('573015550002'), '573015550002');
      },
    );

    test('construye la URL de wa.me con y sin mensaje codificado', () {
      final uriSimple = WhatsAppLauncher.buildUri(phone: '3015550002');
      expect(uriSimple.toString(), 'https://wa.me/573015550002');

      final uriConMensaje = WhatsAppLauncher.buildUri(
        phone: '3015550002',
        message: 'Hola conductor, voy en camino',
      );
      expect(
        uriConMensaje.toString(),
        'https://wa.me/573015550002?text=Hola%20conductor%2C%20voy%20en%20camino',
      );
    });

    testWidgets('WhatsAppButton muestra el icono y la etiqueta', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const WhatsAppButton(
            phone: '3015550002',
            message: 'Hola',
            label: 'Contactar',
          ),
        ),
      );

      expect(find.text('Contactar'), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_rounded), findsOneWidget);
    });
  });
}
