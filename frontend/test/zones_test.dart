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

    test('conserva los barrios históricos del diseño con sus minutos', () {
      const legacy = <String>[
        'Centro',
        'Manga',
        'Bocagrande',
        'Getsemaní',
        'Crespo',
        'El Bosque',
        'La Popa',
        'Turbaco',
      ];
      for (final name in legacy) {
        final zone = Zones.neighborhoods.firstWhere(
          (item) => item.name == name,
          orElse: () => throw StateError('Falta $name del catálogo'),
        );
        expect(zone.minutes, greaterThan(0), reason: '$name minutos');
        expect(zone.isCampus, isFalse, reason: name);
      }
    });

    test('la lista del menú no repite nombres y cubre la base ampliada', () {
      expect(Zones.neighborhoodNames.length, greaterThanOrEqualTo(120));
      final normalized = Zones.neighborhoodNames.map(Zones.normalize).toList();
      expect(normalized.toSet().length, normalized.length);
      expect(Zones.neighborhoodNames, contains('La Boquilla'));
      expect(Zones.neighborhoodNames, contains('El Pozón'));
      expect(Zones.neighborhoodNames, contains('Tierrabomba'));
      expect(Zones.neighborhoodNames, contains('Pontezuela'));
    });

    test('el filtro pone primero los nombres que empiezan por el texto', () {
      final filtered = Zones.filterNeighborhoodNames('m');
      expect(filtered.take(4).toList(), <String>[
        'Manga',
        'Manzanillo del Mar',
        'Marbella',
        'Membrillal',
      ]);
      expect(filtered.indexOf('Manga'), lessThan(filtered.indexOf('La María')));
      expect(
        filtered.indexOf('La María'),
        lessThan(filtered.indexOf('Almirante Colón')),
      );
    });

    test(
      'el filtro no devuelve todo el catálogo cuando no hay coincidencias',
      () {
        expect(Zones.filterNeighborhoodNames('zzzz'), isEmpty);
        expect(
          Zones.filterNeighborhoodNames(
            '',
            hidden: {'Manga'},
          ).contains('Manga'),
          isFalse,
        );
      },
    );

    test('todo el catálogo resuelto tiene coordenadas de Cartagena', () {
      for (final zone in Zones.all) {
        expect(zone.latitude, greaterThan(9.5), reason: '${zone.name} latitud');
        expect(zone.latitude, lessThan(11.0), reason: '${zone.name} latitud');
        expect(
          zone.longitude,
          greaterThan(-76.0),
          reason: '${zone.name} longitud',
        );
        expect(
          zone.longitude,
          lessThan(-75.0),
          reason: '${zone.name} longitud',
        );
      }

      for (final zone in Zones.neighborhoods) {
        expect(zone.minutes, greaterThan(0), reason: '${zone.name} minutos');
        expect(zone.isCampus, isFalse, reason: zone.name);
      }
    });

    test('un barrio nuevo se registra con su coordenada de la fuente', () {
      const resolved = Zone(
        name: 'Barrio de prueba',
        minutes: 30,
        latitude: 10.4,
        longitude: -75.5,
      );
      expect(Zones.byName('Barrio de prueba'), isNull);

      Zones.registerResolvedZone(resolved);
      expect(Zones.byName('Barrio de prueba')?.latitude, 10.4);
      expect(Zones.byName('barrio de prueba')?.name, 'Barrio de prueba');
      expect(
        Zones.neighborhoods.any((zone) => zone.name == 'Barrio de prueba'),
        isTrue,
      );
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
