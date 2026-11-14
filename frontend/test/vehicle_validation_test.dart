import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/profile/data/vehicle_validation.dart';

void main() {
  group('normalizeVehiclePlate', () {
    test('acepta placas de automóvil', () {
      expect(normalizeVehiclePlate('XYZ-123'), 'XYZ-123');
      expect(normalizeVehiclePlate('xyz 123'), 'XYZ-123');
      expect(normalizeVehiclePlate('abc-123'), 'ABC-123');
    });

    test('rechaza formatos que no son de automóvil colombiano', () {
      expect(normalizeVehiclePlate('123-XYZ'), isNull);
      expect(normalizeVehiclePlate('AB-123'), isNull);
      expect(normalizeVehiclePlate('ABCD-123'), isNull);
      expect(normalizeVehiclePlate('ABC-1234'), isNull);
      expect(normalizeVehiclePlate('ABC-12'), isNull);
      expect(normalizeVehiclePlate('ABC-12D'), isNull);
      expect(normalizeVehiclePlate(''), isNull);
    });

    test('el mensaje del campo explica el formato esperado', () {
      expect(validateVehiclePlate('XYZ-123'), isNull);
      expect(validateVehiclePlate('123'), contains('placa colombiana'));
    });
  });

  group('validateVehicleModel y validateVehicleColor', () {
    test('exigen al menos dos caracteres y respetan el máximo', () {
      expect(validateVehicleModel('Chevrolet Spark'), isNull);
      expect(validateVehicleModel(' C '), isNotNull);
      expect(validateVehicleModel('x' * 51), isNotNull);

      expect(validateVehicleColor('Gris'), isNull);
      expect(validateVehicleColor(' G '), isNotNull);
      expect(validateVehicleColor('x' * 31), isNotNull);
    });
  });
}
