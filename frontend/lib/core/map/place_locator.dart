import 'dart:math' as math;

import 'package:flutter/widgets.dart';
<<<<<<< HEAD
=======
import 'package:http/http.dart' as http;
>>>>>>> origin/master
import 'package:latlong2/latlong.dart';

import '../config/maps_config.dart';
import '../constants/zones.dart';
import '../network/google_maps_service.dart';

/// Resuelve un origen o destino a coordenadas, y opcionalmente la geometría
/// de la calle entre dos puntos.
///
/// El backend solo guarda texto. El orden de resolución es:
<<<<<<< HEAD
/// 1. Google Maps (Geocoding / Routes API), si hay clave configurada.
/// 2. El catálogo de barrios, si el texto coincide.
=======
/// 1. Google Maps (Geocoding / Routes API), si la API Key está activa.
/// 2. Nominatim / OSRM (OpenStreetMap), acotado a Cartagena.
/// 3. El catálogo de barrios, si el texto coincide.
>>>>>>> origin/master
///
/// Las respuestas se cachean en memoria para no gastar cuota de la API.
class PlaceLocator {
<<<<<<< HEAD
  PlaceLocator({GoogleMapsService? googleMapsService})
    : _googleMaps = googleMapsService ?? GoogleMapsService.instance;
=======
  PlaceLocator({
    http.Client? client,
    GoogleMapsService? googleMapsService,
    this.minInterval = const Duration(seconds: 1),
    this.timeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client(),
       _googleMaps = googleMapsService,
       _isCustomClient = client != null;
>>>>>>> origin/master

  /// Instancia compartida por los mapas de la app.
  static PlaceLocator instance = PlaceLocator();

<<<<<<< HEAD
  final GoogleMapsService _googleMaps;
=======
  /// Cabecera que Nominatim exige para identificar al cliente.
  static const String userAgent =
      'ROUTB/1.0 (co.iscoutb.routb; UTB student carpooling)';

  /// Caja de búsqueda: Cartagena y Turbaco.
  static const String _viewbox = '-75.65,10.55,-75.35,10.00';

  final http.Client _client;
  final GoogleMapsService? _googleMaps;
  final bool _isCustomClient;
  final Duration minInterval;
  final Duration timeout;
>>>>>>> origin/master

  final Map<String, LatLng?> _geocodeCache = <String, LatLng?>{};
  final Map<String, List<LatLng>?> _routeCache = <String, List<LatLng>?>{};

<<<<<<< HEAD
=======
  Future<void> _nominatimGate = Future<void>.value();
  DateTime _lastNominatim = DateTime.fromMillisecondsSinceEpoch(0);

  bool get _useRemote {
    final name = WidgetsBinding.instance.runtimeType.toString();
    return !name.contains('TestWidgetsFlutterBinding');
  }

>>>>>>> origin/master
  /// Punto del catálogo, o `null` si el texto no es un barrio conocido.
  static LatLng? catalogPoint(String? raw) {
    final zone = Zones.byName(raw);
    return zone == null ? null : Zones.pointOf(zone);
  }

  /// Coordenada geocodificada que ya está en caché, sin hacer una petición.
  ///
  /// Las vistas previas pueden montarse de nuevo mientras la pantalla cambia
  /// de estado. Si ya se conoce la coordenada real, permite pintarla desde el
  /// primer frame en vez de volver brevemente al punto aproximado del catálogo.
  LatLng? cachedPoint(String query) {
    final key = Zones.normalize(query.trim());
    if (key.isEmpty || !_geocodeCache.containsKey(key)) return null;
    return _geocodeCache[key];
  }

<<<<<<< HEAD
  /// Coordenada más fiel al texto: Google Maps y, si falla, el catálogo.
=======
  /// Coordenada más fiel al texto: Google Maps, Nominatim y, si falla, el catálogo.
>>>>>>> origin/master
  Future<LatLng?> locate(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return null;

    final key = Zones.normalize(trimmed);
    final catalog = catalogPoint(trimmed);

    if (_geocodeCache.containsKey(key)) {
      return _geocodeCache[key] ?? catalog;
    }

    LatLng? geocoded;
<<<<<<< HEAD
    try {
      geocoded = await _googleMaps.geocodeAddress(trimmed);
    } on Object {
      geocoded = null;
    }
=======
    if (!_isCustomClient && MapsConfig.hasApiKey && _useRemote) {
      final gmaps = _googleMaps ?? GoogleMapsService.instance;
      geocoded = await gmaps.geocodeAddress(trimmed);
    }
    geocoded ??= await _geocodeNominatim(trimmed);
>>>>>>> origin/master
    _geocodeCache[key] = geocoded;
    return geocoded ?? catalog;
  }

<<<<<<< HEAD
  /// Geometría de la vía entre [start] y [end] mediante Google Routes API.
=======
  /// Geometría de la vía entre [start] y [end], con Google Routes API u OSRM.
>>>>>>> origin/master
  Future<List<LatLng>?> route(LatLng start, LatLng end) async {
    if (_almostSame(start, end)) return <LatLng>[start, end];

    final key = _routeKey(start, end);
    if (_routeCache.containsKey(key)) return _routeCache[key];

    List<LatLng>? geometry;
<<<<<<< HEAD
    try {
      final googleRoute = await _googleMaps.computeRoute(
=======
    if (!_isCustomClient && MapsConfig.hasApiKey && _useRemote) {
      final gmaps = _googleMaps ?? GoogleMapsService.instance;
      final googleRoute = await gmaps.computeRoute(
>>>>>>> origin/master
        origin: start,
        destination: end,
      );
      if (googleRoute != null && googleRoute.polyline.length >= 2) {
        geometry = googleRoute.polyline;
      }
<<<<<<< HEAD
    } on Object {
      geometry = null;
    }

=======
    }

    geometry ??= await _osrmRoute(start, end);
>>>>>>> origin/master
    _routeCache[key] = geometry;
    return geometry;
  }

  /// Geometría de la vía pasando por un desvío o parada intermedia [waypoint].
  Future<List<LatLng>?> routeWithWaypoint(
    LatLng start,
    LatLng end,
    LatLng waypoint,
  ) => routeWithWaypoints(start, end, <LatLng>[waypoint]);
<<<<<<< HEAD
=======

  /// Geometría de la vía pasando por múltiples desvíos o paradas intermedias [waypoints].
  Future<List<LatLng>?> routeWithWaypoints(
    LatLng start,
    LatLng end,
    List<LatLng> waypoints,
  ) async {
    final validWaypoints = waypoints
        .where((wp) => !_almostSame(start, wp) && !_almostSame(end, wp))
        .toList(growable: false);

    if (validWaypoints.isEmpty) return route(start, end);

    if (!_isCustomClient && MapsConfig.hasApiKey && _useRemote) {
      final gmaps = _googleMaps ?? GoogleMapsService.instance;
      final googleRoute = await gmaps.computeRoute(
        origin: start,
        destination: end,
        waypoints: validWaypoints,
      );
      if (googleRoute != null && googleRoute.polyline.length >= 2) {
        return googleRoute.polyline;
      }
    }

    final points = <LatLng>[start, ...validWaypoints, end];
    final fullRoute = <LatLng>[];
    for (var i = 0; i < points.length - 1; i++) {
      final leg = await route(points[i], points[i + 1]);
      if (leg != null && leg.isNotEmpty) {
        if (fullRoute.isNotEmpty && leg.first == fullRoute.last) {
          fullRoute.addAll(leg.skip(1));
        } else {
          fullRoute.addAll(leg);
        }
      }
    }
    if (fullRoute.length >= 2) return fullRoute;
    return route(start, end);
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
>>>>>>> origin/master

  /// Geometría de la vía pasando por múltiples desvíos o paradas intermedias [waypoints].
  Future<List<LatLng>?> routeWithWaypoints(
    LatLng start,
    LatLng end,
    List<LatLng> waypoints,
  ) async {
    final validWaypoints = waypoints
        .where((wp) => !_almostSame(start, wp) && !_almostSame(end, wp))
        .toList(growable: false);

    if (validWaypoints.isEmpty) return route(start, end);

    try {
      final googleRoute = await _googleMaps.computeRoute(
        origin: start,
        destination: end,
        waypoints: validWaypoints,
      );
      if (googleRoute != null && googleRoute.polyline.length >= 2) {
        return googleRoute.polyline;
      }
<<<<<<< HEAD
=======

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
            LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble()),
      ];
>>>>>>> origin/master
    } on Object {
      // Si Google falla, se intentan los tramos por separado.
    }

    final points = <LatLng>[start, ...validWaypoints, end];
    final fullRoute = <LatLng>[];
    for (var i = 0; i < points.length - 1; i++) {
      final leg = await route(points[i], points[i + 1]);
      if (leg != null && leg.isNotEmpty) {
        if (fullRoute.isNotEmpty && leg.first == fullRoute.last) {
          fullRoute.addAll(leg.skip(1));
        } else {
          fullRoute.addAll(leg);
        }
      }
<<<<<<< HEAD
    }
    if (fullRoute.length >= 2) return fullRoute;
    return route(start, end);
=======
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
    if (lower.contains('turbaco') || lower.contains('arjona')) {
      return lower.contains('bolivar') || lower.contains('bolívar')
          ? raw
          : '$raw, Bolívar, Colombia';
    }
    return '$raw, Cartagena, Bolívar, Colombia';
>>>>>>> origin/master
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
