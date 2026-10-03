import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/constants/zones.dart';

void main() {
  group('Zones.byName', () {
    test('resuelve el nombre con o sin tilde y en cualquier caja', () {
      expect(Zones.byName('Getsemaní')?.name, 'Getsemaní');
      expect(Zones.byName('getsemani')?.name, 'Getsemaní');
      expect(Zones.byName('GETSEMANÍ')?.name, 'Getsemaní');
      expect(Zones.byName('Getsemani')?.name, 'Getsemaní');
      expect(Zones.byName('  centro ')?.name, 'Centro');
    });

    test('acepta los alias que la gente escribe de otras formas', () {
      expect(Zones.byName('UTB')?.isCampus, isTrue);
      expect(Zones.byName('utb')?.isCampus, isTrue);
      expect(
        Zones.byName('Universidad Tecnológica de Bolívar')?.isCampus,
        isTrue,
      );
      expect(Zones.byName('Centro Histórico')?.name, 'Centro');
      expect(Zones.byName('Boca grande')?.name, 'Bocagrande');
    });

    test('devuelve null cuando el lugar no está en el catálogo', () {
      expect(Zones.byName(null), isNull);
      expect(Zones.byName(''), isNull);
      expect(Zones.byName('Cercano al parque'), isNull);
    });
  });

  group('catálogo', () {
    test('la universidad no aporta distancia porque es el extremo fijo', () {
      expect(Zones.campus.minutes, 0);
      expect(Zones.campus.isCampus, isTrue);
    });

    test('los ocho barrios del diseño están con sus minutos', () {
      expect(
        Zones.neighborhoods.map((zone) => zone.name),
        <String>[
          'Centro',
          'Manga',
          'Bocagrande',
          'Getsemaní',
          'Crespo',
          'El Bosque',
          'La Popa',
          'Turbaco',
        ],
      );
      expect(
        Zones.neighborhoods.map((zone) => zone.minutes),
        <int>[25, 22, 30, 26, 28, 18, 24, 20],
      );
    });

    test('todo el catálogo tiene coordenadas de Cartagena', () {
      for (final zone in Zones.all) {
        expect(zone.latitude, greaterThan(9.5), reason: '${zone.name} latitud');
        expect(zone.latitude, lessThan(11.0), reason: '${zone.name} latitud');
        expect(zone.longitude, greaterThan(-76.0), reason: '${zone.name} longitud');
        expect(zone.longitude, lessThan(-75.0), reason: '${zone.name} longitud');
      }

      // La universidad es el extremo fijo, así que no aporta minutos; los
      // barrios sí, y son los que alimentan la hora de llegada estimada.
      for (final zone in Zones.neighborhoods) {
        expect(zone.minutes, greaterThan(0), reason: '${zone.name} minutos');
        expect(zone.isCampus, isFalse, reason: zone.name);
      }
    });

    test('el punto de la universidad se puede leer como LatLng', () {
      expect(Zones.campusPoint.latitude, Zones.campus.latitude);
      expect(Zones.campusPoint.longitude, Zones.campus.longitude);
      expect(Zones.pointOf(Zones.campus).latitude, Zones.campus.latitude);
    });

    test('normalize quita tildes, baja la caja y limpia espacios', () {
      expect(Zones.normalize('  El  Bosque '), 'el bosque');
      expect(Zones.normalize('TURBACO'), 'turbaco');
      expect(Zones.normalize('Peña'), 'pena');
    });

    test('isCampus reconoce la universidad con cualquier escritura', () {
      expect(Zones.isCampus('UTB'), isTrue);
      expect(Zones.isCampus('utb'), isTrue);
      expect(Zones.isCampus('Centro'), isFalse);
      expect(Zones.isCampus(null), isFalse);
    });
  });
}