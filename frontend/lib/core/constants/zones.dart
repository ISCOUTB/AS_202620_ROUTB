import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

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
abstract final class Zones {
  /// Universidad Tecnológica de Bolívar, sede de Cerro de la Popa.
  static const Zone campus = Zone(
    name: 'UTB',
    minutes: 0,
    latitude: 10.4216,
    longitude: -75.5440,
    isCampus: true,
  );

  /// Barrios offered en el selector de trayecto del conductor, en el orden en
  /// que los muestra el diseño.
  static const List<Zone> neighborhoods = <Zone>[
    Zone(name: 'Centro', minutes: 25, latitude: 10.4236, longitude: -75.5477),
    Zone(name: 'Manga', minutes: 22, latitude: 10.4383, longitude: -75.5247),
    Zone(name: 'Bocagrande', minutes: 30, latitude: 10.4697, longitude: -75.5466),
    Zone(name: 'Getsemaní', minutes: 26, latitude: 10.4510, longitude: -75.5200),
    Zone(name: 'Crespo', minutes: 28, latitude: 10.4520, longitude: -75.5260),
    Zone(name: 'El Bosque', minutes: 18, latitude: 10.4390, longitude: -75.5180),
    Zone(name: 'La Popa', minutes: 24, latitude: 10.4216, longitude: -75.5350),
    Zone(name: 'Turbaco', minutes: 20, latitude: 10.0900, longitude: -75.4400),
  ];

  /// Todos los lugares conocidos, con la universidad primero.
  static const List<Zone> all = <Zone>[campus, ...neighborhoods];

  /// Nombres alternativos que se aceptan al resolver una zona.
  static const Map<String, String> _aliases = <String, String>{
    'universidad tecnologica de bolivar': 'UTB',
    'utb': 'UTB',
    'la universidad': 'UTB',
    'centro historico': 'Centro',
    'el centro': 'Centro',
    'centro histórico': 'Centro',
    'boca grande': 'Bocagrande',
    'getsemani': 'Getsemaní',
    'el bosque': 'El Bosque',
    'bosque': 'El Bosque',
    'la popa': 'La Popa',
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

  /// Minúsculas, sin tildes y sin espacios sobrantes.
  static String normalize(String raw) {
    final lowered = raw.trim().toLowerCase();
    final buffer = StringBuffer();
    for (final unit in lowered.split('')) {
      buffer.write(_accents[unit] ?? unit);
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Resuelve un texto libre a una zona conocida, o `null` si no aparece en el
  /// catálogo.
  static Zone? byName(String? raw) {
    if (raw == null) return null;
    final normalized = normalize(raw);
    if (normalized.isEmpty) return null;

    final alias = _aliases[normalized];
    if (alias != null) return _byCanonical(alias);

    for (final zone in all) {
      if (normalize(zone.name) == normalized) return zone;
    }
    return null;
  }

  static Zone? _byCanonical(String name) {
    for (final zone in all) {
      if (zone.name == name) return zone;
    }
    return null;
  }

  /// `true` si el texto corresponde a la universidad.
  static bool isCampus(String? raw) => byName(raw)?.isCampus ?? false;

  /// Coordenada de la universidad como `LatLng`, para los mapas.
  static LatLng get campusPoint => LatLng(campus.latitude, campus.longitude);

  /// Coordenada de [zone] como `LatLng`.
  static LatLng pointOf(Zone zone) => LatLng(zone.latitude, zone.longitude);
}