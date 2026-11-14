import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/auth/data/auth_validation.dart';

void main() {
  group('normalizePhone', () {
    test('acepta los formatos colombianos permitidos', () {
      expect(normalizePhone('3001234567'), '3001234567');
      expect(normalizePhone('573001234567'), '3001234567');
      expect(normalizePhone('+573001234567'), '3001234567');
      expect(normalizePhone('+57 300-123-4567'), '3001234567');
    });

    test('rechaza prefijos incompletos y longitudes erróneas', () {
      for (final value in <String>[
        '',
        '300123456',
        '30012345678',
        '+57300123456',
        '1234567890',
        '30012345ab',
      ]) {
        expect(normalizePhone(value), isNull, reason: value);
      }
    });
  });

  group('validateNewPassword', () {
    test('exige entre 8 y 128 caracteres', () {
      expect(validateNewPassword('1234567'), isNotNull);
      expect(validateNewPassword('12345678'), isNull);
      expect(validateNewPassword('x' * 128), isNull);
      expect(validateNewPassword('x' * 129), isNotNull);
    });
  });

  group('validateName', () {
    test('exige entre 2 y 50 caracteres sin contar extremos', () {
      expect(validateName(' J ', 'nombre'), isNotNull);
      expect(validateName('Juan', 'nombre'), isNull);
      expect(validateName('x' * 51, 'apellido'), isNotNull);
    });
  });
}
