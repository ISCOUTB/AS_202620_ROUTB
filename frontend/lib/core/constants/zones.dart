import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import 'neighborhood_coordinates.g.dart';
import 'neighborhood_names.dart';

/// Barrio de Cartagena que aparece como origen o destino de un viaje.
///
/// La API guarda `origin` y `destination` como texto libre, así que [Zones.byName]
/// resuelve la coincidencia en el cliente.
@immutable
class Zone {
  const Zone({
    required this.name,
    required this.minutes,
    required this.latitude,
    required this.longitude,
    this.isCampus = false,
  });

  /// Nombre tal como se muestra y se envía: «Getsemaní».
  final String name;

  /// Minutos estimados de trayecto desde o hacia este barrio.
  ///
  /// Los valores salen de la tabla del diseño y son aproximados: el backend no
  /// calcula ni guarda tiempos de recorrido. Para ajustarlos basta cambiar este
  /// campo y todo lo demás (ETA, «En curso») se recalcula.
  final int minutes;

  /// Latitud en grados decimales.
  final double latitude;

  /// Longitud en grados decimales.
  final double longitude;

  /// `true` para la universidad, que es el extremo fijo de casi todos los
  /// trayectos y por eso no aporta distancia.
  final bool isCampus;

  @override
  bool operator ==(Object other) =>
      other is Zone &&
      other.name == name &&
      other.minutes == minutes &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.isCampus == isCampus;

  @override
  int get hashCode => Object.hash(name, minutes, latitude, longitude, isCampus);

  @override
  String toString() => name;
}

/// Catálogo de zonas que ROUTB reconoce.
///
/// [neighborhoodNames] es la lista completa que ve el menú. [neighborhoods]
/// solo contiene los barrios con coordenada verificada: los del catálogo
/// histórico y los que el generador o la geocodificación en caliente hayan
/// resuelto. Un nombre sin coordenada se ubica al elegirlo y, si la fuente no
/// lo encuentra, se oculta del menú.
abstract final class Zones {
  /// Universidad Tecnológica de Bolívar, sede de Cerro de la Popa.
  static const Zone campus = Zone(
    name: 'UTB',
    minutes: 0,
    latitude: 10.371078,
    longitude: -75.466261,
    isCampus: true,
  );

  /// Coordenadas del catálogo anterior a la lista ampliada.
  ///
  /// Se conservan mientras el generador no las reemplace con la fuente
  /// geográfica; así los viajes ya publicados no cambian de punto ni de ETA.
  static const Map<String, ({double latitude, double longitude, int minutes})>
  _legacy = <String, ({double latitude, double longitude, int minutes})>{
    'centro': (latitude: 10.4236, longitude: -75.5477, minutes: 25),
    'manga': (latitude: 10.4130, longitude: -75.5350, minutes: 22),
    'bocagrande': (latitude: 10.4000, longitude: -75.5530, minutes: 30),
    'getsemani': (latitude: 10.4215, longitude: -75.5450, minutes: 26),
    'crespo': (latitude: 10.4500, longitude: -75.5180, minutes: 28),
    'el bosque': (latitude: 10.3950, longitude: -75.5150, minutes: 18),
    'la popa': (latitude: 10.4216, longitude: -75.5350, minutes: 24),
    'turbaco': (latitude: 10.3340, longitude: -75.4160, minutes: 20),
  };

  /// Coordenadas resueltas durante la sesión por el buscador.
  static final List<Zone> _resolvedThisSession = <Zone>[];

  /// Nombres alternativos que se aceptan al resolver una zona.
  static const Map<String, String> _aliases = <String, String>{
    'universidad tecnologica de bolivar': 'UTB',
    'utb': 'UTB',
    'la universidad': 'UTB',
    'centro historico': 'Centro',
    'el centro': 'Centro',
    'ciudad amurallada': 'Centro',
    'boca grande': 'Bocagrande',
    'getsemani': 'Getsemaní',
    'boquilla': 'La Boquilla',
    'bosque': 'El Bosque',
    'campestre': 'El Campestre',
    'calamares': 'Los Calamares',
    'popa': 'La Popa',
  };

  static const Map<String, String> _accents = <String, String>{
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
  };

  /// Nombres completos que ofrece el menú de ubicación.
  static const List<String> neighborhoodNames = cartagenaNeighborhoodNames;

  /// Minúsculas, sin tildes y sin espacios sobrantes.
  static String normalize(String raw) {
    final lowered = raw.trim().toLowerCase();
    final buffer = StringBuffer();
    for (final unit in lowered.split('')) {
      buffer.write(_accents[unit] ?? unit);
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Filtra la lista del menú y pone primero los nombres que empiezan por el
  /// texto escrito, luego los que tienen una palabra que empieza igual y al
  /// final los que solo lo contienen.
  static List<String> filterNeighborhoodNames(
    String query, {
    Set<String> hidden = const <String>{},
  }) {
    final names = cartagenaNeighborhoodNames
        .where((name) => !hidden.contains(name))
        .toList(growable: false);
    final normalizedQuery = normalize(query);
    if (normalizedQuery.isEmpty) return names;

    int rank(String name) {
      final normalizedName = normalize(name);
      if (normalizedName.startsWith(normalizedQuery)) return 0;
      if (normalizedName
          .split(RegExp(r'\s+'))
          .any((word) => word.startsWith(normalizedQuery))) {
        return 1;
      }
      if (normalizedName.contains(normalizedQuery)) return 2;
      return 3;
    }

    final matches = names.where((name) => rank(name) < 3).toList();
    matches.sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      if (byRank != 0) return byRank;
      return normalize(a).compareTo(normalize(b));
    });
    return matches;
  }

  /// Resuelve un texto libre a una zona conocida, o `null` si el nombre no
  /// tiene coordenada verificada o no aparece en el catálogo.
  static Zone? byName(String? raw) {
    if (raw == null) return null;
    final normalized = normalize(raw);
    if (normalized.isEmpty) return null;
    if (normalized == 'utb') return campus;

    for (final name in cartagenaNeighborhoodNames) {
      if (normalize(name) == normalized) {
        return _zoneFor(name);
      }
    }

    for (final zone in _resolvedThisSession) {
      if (normalize(zone.name) == normalized) return zone;
    }

    final alias = _aliases[normalized];
    if (alias != null) return byName(alias);
    return null;
  }

  /// Barrios con coordenada disponible. No incluye los nombres que todavía no
  /// se han podido ubicar.
  static List<Zone> get neighborhoods {
    final zones = <Zone>[];
    final seen = <String>{};
    for (final name in cartagenaNeighborhoodNames) {
      final zone = _zoneFor(name);
      if (zone == null) continue;
      if (seen.add(normalize(zone.name))) zones.add(zone);
    }
    for (final zone in _resolvedThisSession) {
      if (seen.add(normalize(zone.name))) zones.add(zone);
    }
    return List<Zone>.unmodifiable(zones);
  }

  /// Todos los lugares conocidos, con la universidad primero.
  static List<Zone> get all =>
      List<Zone>.unmodifiable(<Zone>[campus, ...neighborhoods]);

  /// `true` si el texto corresponde a la universidad.
  static bool isCampus(String? raw) => byName(raw)?.isCampus ?? false;

  /// Coordenada de la universidad como `LatLng`, para los mapas.
  static LatLng get campusPoint => LatLng(campus.latitude, campus.longitude);

  /// Coordenada de [zone] como `LatLng`.
  static LatLng pointOf(Zone zone) => LatLng(zone.latitude, zone.longitude);

  /// `true` si la coordenada cae en el área urbana o rural de Cartagena y
  /// Turbaco. Se usa para descartar resultados que el geocodificador devuelve
  /// en otro municipio.
  static bool isInsideCartagena(double latitude, double longitude) =>
      latitude >= 10.0 &&
      latitude <= 10.7 &&
      longitude >= -75.9 &&
      longitude <= -75.2;

  /// Estima los minutos desde el campus para un barrio recién ubicado.
  ///
  /// Solo se usa cuando la fuente geográfica no trae un tiempo propio. La
  /// velocidad urbana es deliberadamente conservadora para no prometer
  /// llegadas que el tráfico de Cartagena no cumple.
  static int estimateMinutes(double latitude, double longitude) {
    final kilometers = const Distance().as(
      LengthUnit.Kilometer,
      campusPoint,
      LatLng(latitude, longitude),
    );
    final minutes = (kilometers / 18.0 * 60).round();
    return minutes.clamp(10, 90).toInt();
  }

  /// Guarda un barrio ubicado durante la sesión para que el menú, las rutas y
  /// los mapas lo resuelvan sin repetir la petición.
  static void registerResolvedZone(Zone zone) {
    if (zone.isCampus) return;
    final key = normalize(zone.name);
    _resolvedThisSession.removeWhere((item) => normalize(item.name) == key);
    _resolvedThisSession.add(zone);
  }

  static Zone? _zoneFor(String name) {
    final legacy = _legacy[normalize(name)];
    final generated = neighborhoodCoordinates[name];
    if (generated != null) {
      return Zone(
        name: name,
        minutes:
            legacy?.minutes ?? estimateMinutes(generated.lat, generated.lng),
        latitude: generated.lat,
        longitude: generated.lng,
      );
    }

    if (legacy != null) {
      return Zone(
        name: name,
        minutes: legacy.minutes,
        latitude: legacy.latitude,
        longitude: legacy.longitude,
      );
    }

    for (final zone in _resolvedThisSession) {
      if (normalize(zone.name) == normalize(name)) return zone;
    }
    return null;
  }
}
