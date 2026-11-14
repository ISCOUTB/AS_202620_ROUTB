import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/services/device_launcher.dart';

void main() {
  group('DeviceLauncher', () {
    test('abre el marcador con el teléfono limpio', () async {
      final uris = <Uri>[];
      final launcher = DeviceLauncher(
        launchUri: (uri) async {
          uris.add(uri);
          return true;
        },
      );

      expect(await launcher.call('+57 300 123 4567'), isTrue);
      expect(uris.single.scheme, 'tel');
      expect(uris.single.path, '+573001234567');
    });

    test('prepara el SMS con el cuerpo escrito', () async {
      final uris = <Uri>[];
      final launcher = DeviceLauncher(
        launchUri: (uri) async {
          uris.add(uri);
          return true;
        },
      );

      expect(
        await launcher.sms('3001234567', message: 'Voy en camino'),
        isTrue,
      );
      expect(uris.single.scheme, 'sms');
      expect(uris.single.path, '3001234567');
      expect(uris.single.queryParameters['body'], 'Voy en camino');
    });

    test('normaliza el móvil colombiano para WhatsApp', () async {
      final uris = <Uri>[];
      final launcher = DeviceLauncher(
        launchUri: (uri) async {
          uris.add(uri);
          return true;
        },
      );

      expect(await launcher.whatsapp('3001234567', message: 'Hola'), isTrue);
      expect(uris.single.host, 'wa.me');
      expect(uris.single.path, '/573001234567');
      expect(uris.single.queryParameters['text'], 'Hola');
    });

    test('prepara el correo con asunto y cuerpo', () async {
      final uris = <Uri>[];
      final launcher = DeviceLauncher(
        launchUri: (uri) async {
          uris.add(uri);
          return true;
        },
      );

      expect(
        await launcher.email(
          'soporte@routb.app',
          subject: 'Ayuda',
          body: 'Necesito ayuda',
        ),
        isTrue,
      );
      expect(uris.single.scheme, 'mailto');
      expect(uris.single.path, 'soporte@routb.app');
      expect(uris.single.queryParameters['subject'], 'Ayuda');
      expect(uris.single.queryParameters['body'], 'Necesito ayuda');
    });

    test('no intenta abrir un teléfono vacío', () async {
      var called = false;
      final launcher = DeviceLauncher(
        launchUri: (uri) async {
          called = true;
          return true;
        },
      );

      expect(await launcher.call('   '), isFalse);
      expect(called, isFalse);
    });
  });
}
