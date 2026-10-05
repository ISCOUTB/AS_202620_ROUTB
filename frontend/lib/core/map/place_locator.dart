import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../constants/zones.dart';

/// Resuelve un origen o destino a coordenadas, y opcionalmente la geometría
/// de la calle entre dos puntos.
///
/// El backend solo guarda texto. El orden de resolución es:
/// 1. Nominatim (OpenStreetMap), acotado a Cartagena.
/// 2. El catálogo de barrios, si el texto coincide.
///
/// Las respuestas se cachean y las peticiones a Nominatim van en fila con
/// al menos un segundo de separación, que es lo que pide su política de uso.
class PlaceLocator {
  PlaceLocator({
    http.Client? client,
    this.minInterval = const Duration(seconds: 1),
    this.timeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client();

  /// Instancia compartida por los mapas de la app.
  static PlaceLocator instance = PlaceLocator();

  /// Cabecera que Nominatim exige para identificar al cliente.
  static const String userAgent =
      'ROUTB/1.0 (co.iscoutb.routb; UTB student carpooling)';

  /// Caja de búsqueda: Cartagena y Turbaco.
  static const String _viewbox = '-75.65,10.55,-75.35,10.00';

  final http.Client _client;
  final Duration minInterval;
  final Duration timeout;

  final Map<String, LatLng?> _geocodeCache = <String, LatLng?>{};
  final Map<String, List<LatLng>?> _routeCache = <String, List<LatLng>?>{};

  Future<void> _nominatimGate = Future<void>.value();
  DateTime _lastNominatim = DateTime.fromMillisecondsSinceEpoch(0);

  /// Punto del catálogo, o `null` si el texto no es un barrio conocido.
  static LatLng? catalogPoint(String? raw) {
    final zone = Zones.byName(raw);
    return zone == null ? null : Zones.pointOf(zone);
  }

  /// Coordenada más fiel al texto: Nominatim y, si falla, el catálogo.
  Future<LatLng?> locate(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return null;

    final key = Zones.normalize(trimmed);
    final catalog = catalogPoint(trimmed);

    if (_geocodeCache.containsKey(key)) {
      return _geocodeCache[key] ?? catalog;
    }

    final geocoded = await _geocodeNominatim(trimmed);
    _geocodeCache[key] = geocoded;
    return geocoded ?? catalog;
  }

  /// Geometría de la vía entre [start] y [end], o `null` si OSRM no responde.
  Future<List<LatLng>?> route(LatLng start, LatLng end) async {
    if (_almostSame(start, end)) return <LatLng>[start, end];

    final key = _routeKey(start, end);
    if (_routeCache.containsKey(key)) return _routeCache[key];

    final geometry = await _osrmRoute(start, end);
    _routeCache[key] = geometry;
    return geometry;
  }

  Future<LatLng?> _geocodeNominatim(String query) {
    return _throughNominatimGate(() async {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': _searchQuery(query),
        'format': 'json',
        'limit': '1',
        'countrycodes': 'co',
        'viewbox': _viewbox,
        'addressdetails': '0',
      });

      final response = await _client
          .get(uri, headers: _headers)
          .timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! List || decoded.isEmpty) return null;
      final first = decoded.first;
      if (first is! Map) return null;

      final lat = double.tryParse('${first['lat']}');
      final lon = double.tryParse('${first['lon']}');
      if (lat == null || lon == null) return null;
      return LatLng(lat, lon);
    });
  }

  Future<List<LatLng>?> _osrmRoute(LatLng start, LatLng end) async {
    try {
      final uri = Uri.https(
        'router.project-osrm.org',
        '/route/v1/driving/'
            '${start.longitude},${start.latitude};'
            '${end.longitude},${end.latitude}',
        {'overview': 'full', 'geometries': 'geojson'},
      );

      final response = await _client
          .get(uri, headers: _headers)
          .timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) return null;
      final routes = decoded['routes'];
      if (routes is! List || routes.isEmpty) return null;
      final geometry = (routes.first as Map)['geometry'];
      if (geometry is! Map) return null;
      final coordinates = geometry['coordinates'];
      if (coordinates is! List || coordinates.length < 2) return null;

      return <LatLng>[
        for (final pair in coordinates)
          if (pair is List && pair.length >= 2)
            LatLng(
              (pair[1] as num).toDouble(),
              (pair[0] as num).toDouble(),
            ),
      ];
    } on Object {
      return null;
    }
  }

  Future<LatLng?> _throughNominatimGate(Future<LatLng?> Function() request) {
    final previous = _nominatimGate;
    final done = Completer<void>();
    _nominatimGate = done.future;

    return previous.then((_) async {
      try {
        final wait = minInterval - DateTime.now().difference(_lastNominatim);
        if (wait > Duration.zero) {
          await Future<void>.delayed(wait);
        }
        _lastNominatim = DateTime.now();
        return await request();
      } on Object {
        return null;
      } finally {
        done.complete();
      }
    });
  }

  Map<String, String> get _headers => <String, String>{
        'User-Agent': userAgent,
        'Accept': 'application/json',
        'Accept-Language': 'es',
      };

  static String _searchQuery(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('cartagena')) return raw;
    return '$raw, Cartagena, Bolívar, Colombia';
  }

  static String _routeKey(LatLng start, LatLng end) {
    String at(LatLng point) =>
        '${point.latitude.toStringAsFixed(5)},${point.longitude.toStringAsFixed(5)}';
    return '${at(start)}|${at(end)}';
  }

  static bool _almostSame(LatLng a, LatLng b) {
    final dLat = a.latitude - b.latitude;
    final dLng = a.longitude - b.longitude;
    return math.sqrt(dLat * dLat + dLng * dLng) < 0.00005;
  }

  /// Deja el cache vacío. Solo se usa en pruebas.
  @visibleForTesting
  void clearCache() {
    _geocodeCache.clear();
    _routeCache.clear();
  }
}
