import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';

import '../constants/zones.dart';
import '../network/google_maps_service.dart';

/// Resuelve un origen o destino a coordenadas, y opcionalmente la geometría
/// de la calle entre dos puntos.
///
/// El backend solo guarda texto. El orden de resolución es:
/// 1. Google Maps (Geocoding / Routes API), si hay clave configurada.
/// 2. El catálogo de barrios, si el texto coincide.
///
/// Las respuestas se cachean en memoria para no gastar cuota de la API.
class PlaceLocator {
  PlaceLocator({GoogleMapsService? googleMapsService})
    : _googleMaps = googleMapsService ?? GoogleMapsService.instance;

  /// Instancia compartida por los mapas de la app.
  static PlaceLocator instance = PlaceLocator();

  final GoogleMapsService _googleMaps;

  final Map<String, LatLng?> _geocodeCache = <String, LatLng?>{};
  final Map<String, List<LatLng>?> _routeCache = <String, List<LatLng>?>{};

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

  /// Coordenada más fiel al texto: Google Maps y, si falla, el catálogo.
  Future<LatLng?> locate(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return null;

    final key = Zones.normalize(trimmed);
    final catalog = catalogPoint(trimmed);

    if (_geocodeCache.containsKey(key)) {
      return _geocodeCache[key] ?? catalog;
    }

    LatLng? geocoded;
    try {
      geocoded = await _googleMaps.geocodeAddress(trimmed);
    } on Object {
      geocoded = null;
    }
    _geocodeCache[key] = geocoded;
    return geocoded ?? catalog;
  }

  /// Geometría de la vía entre [start] y [end] mediante Google Routes API.
  Future<List<LatLng>?> route(LatLng start, LatLng end) async {
    if (_almostSame(start, end)) return <LatLng>[start, end];

    final key = _routeKey(start, end);
    if (_routeCache.containsKey(key)) return _routeCache[key];

    List<LatLng>? geometry;
    try {
      final googleRoute = await _googleMaps.computeRoute(
        origin: start,
        destination: end,
      );
      if (googleRoute != null && googleRoute.polyline.length >= 2) {
        geometry = googleRoute.polyline;
      }
    } on Object {
      geometry = null;
    }

    _routeCache[key] = geometry;
    return geometry;
  }

  /// Geometría de la vía pasando por un desvío o parada intermedia [waypoint].
  Future<List<LatLng>?> routeWithWaypoint(
    LatLng start,
    LatLng end,
    LatLng waypoint,
  ) => routeWithWaypoints(start, end, <LatLng>[waypoint]);

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
    }
    if (fullRoute.length >= 2) return fullRoute;
    return route(start, end);
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
