import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/models/user_profile.dart';
import 'package:frontend/core/models/user_role.dart';

void main() {
  group('UserProfile', () {
    test('lee el perfil con el consentimiento vigente', () {
      // Fecha local, como la interpretaría el dispositivo que la muestra.
      final consent = DateTime(2026, 10, 9, 12);
      final profile = UserProfile.fromJson(<String, dynamic>{
        'id': 7,
        'name': 'Sebastián',
        'last_name': 'Ríos',
        'phone': '3001234567',
        'role': 'driver',
        'location_consent_at': consent.toIso8601String(),
      });

      expect(profile.id, 7);
      expect(profile.fullName, 'Sebastián Ríos');
      expect(profile.initials, 'SR');
      expect(profile.role, UserRole.driver);
      expect(profile.roleLabel, 'Conductor');
      expect(profile.phone, '3001234567');
      expect(profile.hasLocationConsent, isTrue);
      expect(profile.consentLabel, 'Autorizado');
    });

    test('sin consentimiento queda como no autorizada', () {
      final profile = UserProfile.fromJson(<String, dynamic>{
        'id': 8,
        'name': 'Laura',
        'last_name': 'Pasajera',
        'phone': '3007654321',
        'role': 'passenger',
        'location_consent_at': null,
      });

      expect(profile.roleLabel, 'Pasajero');
      expect(profile.hasLocationConsent, isFalse);
      expect(profile.consentLabel, 'Sin autorizar');
    });

    test('tolera un perfil incompleto', () {
      final profile = UserProfile.fromJson(<String, dynamic>{'id': 9});

      expect(profile.fullName, isEmpty);
      expect(profile.initials, '?');
      expect(profile.role, UserRole.passenger);
      expect(profile.hasLocationConsent, isFalse);
    });

    test('lee los datos del vehículo del conductor', () {
      final profile = UserProfile.fromJson(<String, dynamic>{
        'id': 7,
        'name': 'Sebastián',
        'last_name': 'Ríos',
        'phone': '3001234567',
        'role': 'driver',
        'vehicle_model': ' Chevrolet Spark ',
        'vehicle_plate': 'XYZ-123',
        'vehicle_color': 'Gris',
      });

      expect(profile.hasVehicle, isTrue);
      expect(profile.vehicleModel, 'Chevrolet Spark');
      expect(profile.vehiclePlate, 'XYZ-123');
      expect(profile.vehicleColor, 'Gris');
      expect(profile.vehicleLabel, 'Chevrolet Spark · Gris (XYZ-123)');
    });

    test('sin vehículo la ficha queda vacía', () {
      final profile = UserProfile.fromJson(<String, dynamic>{
        'id': 7,
        'role': 'driver',
      });

      expect(profile.hasVehicle, isFalse);
      expect(profile.vehicleLabel, isEmpty);
    });

    test('withVehicle conserva los demás datos y permite limpiar', () {
      final profile = UserProfile.fromJson(<String, dynamic>{
        'id': 7,
        'name': 'Sebastián',
        'last_name': 'Ríos',
        'phone': '3001234567',
        'role': 'driver',
      });

      final conVehiculo = profile.withVehicle(
        model: 'Chevrolet Spark',
        plate: 'XYZ-123',
        color: 'Gris',
      );
      expect(conVehiculo.fullName, 'Sebastián Ríos');
      expect(conVehiculo.vehicleLabel, 'Chevrolet Spark · Gris (XYZ-123)');

      final limpio = conVehiculo.withVehicle();
      expect(limpio.hasVehicle, isFalse);
      expect(limpio.fullName, 'Sebastián Ríos');
    });
  });
}
