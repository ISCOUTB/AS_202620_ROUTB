import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../config/maps_config.dart';

/// Resultado de una ruta calculada con Google Routes API.
class GoogleRouteResult {
  const GoogleRouteResult({
    required this.durationSeconds,
    required this.distanceMeters,
    required this.polyline,
  });

  final int durationSeconds;
  final int distanceMeters;
  final List<LatLng> polyline;

  int get durationMinutes => (durationSeconds / 60).round();
  double get distanceKm => distanceMeters / 1000.0;
}

/// Resultado de cálculo de desvío con punto de parada intermedia.
class RouteDetourResult {
  const RouteDetourResult({
    required this.extraMinutes,
    required this.extraDistanceKm,
    required this.detourDurationSeconds,
    required this.detourDistanceMeters,
    required this.directDurationSeconds,
    required this.directDistanceMeters,
    required this.detourPolyline,
    required this.directPolyline,
  });

  /// Minutos adicionales que implica desviarse a recoger al pasajero.
  final int extraMinutes;

  /// Kilómetros adicionales del desvío.
  final double extraDistanceKm;

  final int detourDurationSeconds;
  final int detourDistanceMeters;
  final int directDurationSeconds;
  final int directDistanceMeters;

  final List<LatLng> detourPolyline;
  final List<LatLng> directPolyline;

  String get summaryLabel {
    final kmText = extraDistanceKm.toStringAsFixed(1);
    if (extraMinutes <= 0) {
      return '+0 min (+$kmText km)';
    }
    return '+$extraMinutes min (+$kmText km)';
  }
}

/// Sugerencia de autocompletado devuelta por Places API (New).
class GooglePlaceSuggestion {
  const GooglePlaceSuggestion({
    required this.placeId,
    required this.text,
    required this.mainText,
    required this.secondaryText,
  });

  final String placeId;
  final String text;
  final String mainText;
  final String secondaryText;
}

/// Coordenadas y dirección detallada de un lugar.
class GooglePlaceDetails {
  const GooglePlaceDetails({
    required this.placeId,
    required this.formattedAddress,
    required this.location,
  });

  final String placeId;
  final String formattedAddress;
  final LatLng location;
}

/// Cliente de Google Maps Platform para geocodificación, autocompletado y
/// cálculo de desvíos en Cartagena.
class GoogleMapsService {
  GoogleMapsService({
    http.Client? client,
    this.timeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client();

  static final GoogleMapsService instance = GoogleMapsService();

  final http.Client _client;
  final Duration timeout;

  // Cachés en memoria para minimizar consumo de cuota de la API key
  final Map<String, String> _reverseCache = <String, String>{};
  final Map<String, LatLng?> _forwardCache = <String, LatLng?>{};
  final Map<String, GoogleRouteResult> _routeCache =
      <String, GoogleRouteResult>{};
  final Map<String, RouteDetourResult> _detourCache =
      <String, RouteDetourResult>{};

  /// Geocodificación inversa: de coordenadas GPS a nomenclatura real de Cartagena.
  Future<String?> reverseGeocode(double lat, double lng) async {
    if (!MapsConfig.hasApiKey) return null;

    final key = '${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)}';
    if (_reverseCache.containsKey(key)) return _reverseCache[key];

    try {
      final uri = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
        'latlng': '$lat,$lng',
        'language': 'es',
        'region': 'co',
        'key': MapsConfig.apiKey,
      });

      final response = await _client.get(uri).timeout(timeout);
      if (response.statusCode != 200) return null;

      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final results = data['results'] as List?;
      if (results == null || results.isEmpty) return null;

      final first = results.first as Map<String, dynamic>;
      final formatted = _formatAddressFromComponents(first);
      if (formatted != null && formatted.isNotEmpty) {
        _reverseCache[key] = formatted;
        return formatted;
      }

      final rawFormatted = first['formatted_address'] as String?;
      if (rawFormatted != null) {
        final cleaned = _cleanFormattedAddress(rawFormatted);
        _reverseCache[key] = cleaned;
        return cleaned;
      }
      return null;
    } on Object catch (error) {
      debugPrint('GoogleMapsService.reverseGeocode error: $error');
      return null;
    }
  }

  /// Geocodificación directa: de texto a coordenadas LatLng en Cartagena.
  Future<LatLng?> geocodeAddress(String query) async {
    if (!MapsConfig.hasApiKey) return null;
    final clean = query.trim();
    if (clean.isEmpty) return null;

    final lower = clean.toLowerCase();
    if (_forwardCache.containsKey(lower)) return _forwardCache[lower];

    try {
      final addressQuery = lower.contains('cartagena')
          ? clean
          : '$clean, Cartagena, Bolívar, Colombia';

      final uri = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
        'address': addressQuery,
        'language': 'es',
        'region': 'co',
        'key': MapsConfig.apiKey,
      });

      final response = await _client.get(uri).timeout(timeout);
      if (response.statusCode != 200) return null;

      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final results = data['results'] as List?;
      if (results == null || results.isEmpty) return null;

      final geometry =
          (results.first as Map<String, dynamic>)['geometry']
              as Map<String, dynamic>?;
      final location = geometry?['location'] as Map<String, dynamic>?;
      if (location == null) return null;

      final lat = (location['lat'] as num?)?.toDouble();
      final lng = (location['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;

      final point = LatLng(lat, lng);
      _forwardCache[lower] = point;
      return point;
    } on Object catch (error) {
      debugPrint('GoogleMapsService.geocodeAddress error: $error');
      return null;
    }
  }

  /// Autocompletado de lugares acotado estrictamente a Cartagena / Turbaco.
  Future<List<GooglePlaceSuggestion>> autocomplete(String query) async {
    if (!MapsConfig.hasApiKey) return const [];
    final clean = query.trim();
    if (clean.length < 2) return const [];

    try {
      final uri = Uri.parse(
        'https://places.googleapis.com/v1/places:autocomplete',
      );
      final body = jsonEncode({
        'input': clean,
        'locationRestriction': {
          'rectangle': {
            'low': {'latitude': 10.25, 'longitude': -75.60},
            'high': {'latitude': 10.55, 'longitude': -75.35},
          },
        },
      });

      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': MapsConfig.apiKey,
            },
            body: body,
          )
          .timeout(timeout);

      if (response.statusCode != 200) return const [];

      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final suggestions = data['suggestions'] as List?;
      if (suggestions == null) return const [];

      final results = <GooglePlaceSuggestion>[];
      for (final item in suggestions) {
        if (item is! Map<String, dynamic>) continue;
        final pred = item['placePrediction'] as Map<String, dynamic>?;
        if (pred == null) continue;

        final placeId = (pred['placeId'] ?? pred['place']) as String? ?? '';
        final textObj = pred['text'] as Map<String, dynamic>?;
        final fullText = textObj?['text'] as String? ?? '';
        final structured = pred['structuredFormat'] as Map<String, dynamic>?;
        final main =
            (structured?['mainText'] as Map<String, dynamic>?)?['text']
                as String? ??
            fullText;
        final sec =
            (structured?['secondaryText'] as Map<String, dynamic>?)?['text']
                as String? ??
            '';

        if (placeId.isNotEmpty && fullText.isNotEmpty) {
          results.add(
            GooglePlaceSuggestion(
              placeId: placeId,
              text: fullText,
              mainText: main,
              secondaryText: sec,
            ),
          );
        }
      }
      return results;
    } on Object catch (error) {
      debugPrint('GoogleMapsService.autocomplete error: $error');
      return const [];
    }
  }

  /// Obtiene coordenadas y dirección de un lugar a partir de su `placeId`.
  Future<GooglePlaceDetails?> getPlaceDetails(String placeId) async {
    if (!MapsConfig.hasApiKey) return null;
    final normalizedId = placeId.startsWith('places/')
        ? placeId.substring(7)
        : placeId;

    try {
      final uri = Uri.parse(
        'https://places.googleapis.com/v1/places/$normalizedId',
      );
      final response = await _client
          .get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': MapsConfig.apiKey,
              'X-Goog-FieldMask': 'id,displayName,location,formattedAddress',
            },
          )
          .timeout(timeout);

      if (response.statusCode != 200) return null;
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final loc = data['location'] as Map<String, dynamic>?;
      if (loc == null) return null;

      final lat = (loc['latitude'] as num?)?.toDouble();
      final lng = (loc['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;

      final formatted =
          data['formattedAddress'] as String? ??
          (data['displayName'] as Map<String, dynamic>?)?['text'] as String? ??
          '';

      return GooglePlaceDetails(
        placeId: normalizedId,
        formattedAddress: _cleanFormattedAddress(formatted),
        location: LatLng(lat, lng),
      );
    } on Object catch (error) {
      debugPrint('GoogleMapsService.getPlaceDetails error: $error');
      return null;
    }
  }

  /// Calcula la ruta y la polilínea exacta usando Google Routes API.
  Future<GoogleRouteResult?> computeRoute({
    required LatLng origin,
    required LatLng destination,
    List<LatLng> waypoints = const <LatLng>[],
  }) async {
    if (!MapsConfig.hasApiKey) return null;

    final routeKey = _buildRouteKey(origin, destination, waypoints);
    if (_routeCache.containsKey(routeKey)) {
      return _routeCache[routeKey];
    }

    try {
      final uri = Uri.parse(
        'https://routes.googleapis.com/directions/v2:computeRoutes',
      );
      final body = <String, dynamic>{
        'origin': {
          'location': {
            'latLng': {
              'latitude': origin.latitude,
              'longitude': origin.longitude,
            },
          },
        },
        'destination': {
          'location': {
            'latLng': {
              'latitude': destination.latitude,
              'longitude': destination.longitude,
            },
          },
        },
        'travelMode': 'DRIVE',
        'routingPreference': 'TRAFFIC_UNAWARE',
      };

      if (waypoints.isNotEmpty) {
        body['intermediates'] = [
          for (final wp in waypoints)
            {
              'location': {
                'latLng': {'latitude': wp.latitude, 'longitude': wp.longitude},
              },
            },
        ];
      }

      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': MapsConfig.apiKey,
              'X-Goog-FieldMask': 'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);

      if (response.statusCode != 200) return null;

      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;

      final route = routes.first as Map<String, dynamic>;
      final durationStr = route['duration'] as String? ?? '0s';
      final durationSeconds =
          int.tryParse(durationStr.replaceAll('s', '')) ?? 0;
      final distanceMeters = (route['distanceMeters'] as num?)?.toInt() ?? 0;

      final polylineObj = route['polyline'] as Map<String, dynamic>?;
      final encoded = polylineObj?['encodedPolyline'] as String? ?? '';
      final points = encoded.isNotEmpty
          ? decodePolyline(encoded)
          : <LatLng>[origin, ...waypoints, destination];

      final result = GoogleRouteResult(
        durationSeconds: durationSeconds,
        distanceMeters: distanceMeters,
        polyline: points,
      );

      _routeCache[routeKey] = result;
      return result;
    } on Object catch (error) {
      debugPrint('GoogleMapsService.computeRoute error: $error');
      return null;
    }
  }

  /// Calcula el desvío comparando la ruta directa vs la ruta con la parada intermedia del pasajero.
  Future<RouteDetourResult?> computeDetour({
    required LatLng origin,
    required LatLng destination,
    required LatLng waypoint,
  }) async {
    final detourKey = _buildRouteKey(origin, destination, [waypoint]);
    if (_detourCache.containsKey(detourKey)) {
      return _detourCache[detourKey];
    }

    // Calcula simultáneamente la ruta directa y la ruta con parada intermedia
    final results = await Future.wait([
      computeRoute(origin: origin, destination: destination),
      computeRoute(
        origin: origin,
        destination: destination,
        waypoints: [waypoint],
      ),
    ]);

    final direct = results[0];
    final detour = results[1];

    if (detour == null) return null;

    final directSec = direct?.durationSeconds ?? 0;
    final directMeters = direct?.distanceMeters ?? 0;
    final detourSec = detour.durationSeconds;
    final detourMeters = detour.distanceMeters;

    final extraSec = math.max(0, detourSec - directSec);
    final extraMin = (extraSec / 60).round();
    final extraMeters = math.max(0, detourMeters - directMeters);
    final extraKm = extraMeters / 1000.0;

    final detourResult = RouteDetourResult(
      extraMinutes: extraMin,
      extraDistanceKm: extraKm,
      detourDurationSeconds: detourSec,
      detourDistanceMeters: detourMeters,
      directDurationSeconds: directSec,
      directDistanceMeters: directMeters,
      detourPolyline: detour.polyline,
      directPolyline: direct?.polyline ?? const [],
    );

    _detourCache[detourKey] = detourResult;
    return detourResult;
  }

  /// Decodifica una polilínea codificada según el algoritmo estándar de Google.
  ///
  /// Se usa `.toSigned(32)` para compatibilidad entre Dart VM y la plataforma Web
  /// (donde los operadores de bits de JavaScript devuelven enteros de 32 bits que
  /// sin el signo adecuado harían desbordar las coordenadas hacia el hemisferio norte).
  static List<LatLng> decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    final len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1))
          .toSigned(32);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1))
          .toSigned(32);
      lng += dlng;

      final latitude = lat / 1E5;
      final longitude = lng / 1E5;
      if (latitude >= -90.0 &&
          latitude <= 90.0 &&
          longitude >= -180.0 &&
          longitude <= 180.0) {
        points.add(LatLng(latitude, longitude));
      }
    }
    return points;
  }

  static String _buildRouteKey(
    LatLng start,
    LatLng end,
    List<LatLng> waypoints,
  ) {
    String at(LatLng p) =>
        '${p.latitude.toStringAsFixed(4)},${p.longitude.toStringAsFixed(4)}';
    final wp = waypoints.map(at).join('|');
    return '${at(start)}->$wp->${at(end)}';
  }

  static String? _formatAddressFromComponents(Map<String, dynamic> result) {
    final components = result['address_components'] as List?;
    if (components == null) return null;

    String? route;
    String? streetNumber;
    String? neighborhood;
    String? locality;

    for (final comp in components) {
      if (comp is! Map<String, dynamic>) continue;
      final types =
          (comp['types'] as List?)?.map((t) => t.toString()).toList() ?? [];
      final longName = comp['long_name'] as String? ?? '';

      if (types.contains('route')) {
        route = longName;
      } else if (types.contains('street_number')) {
        streetNumber = longName;
      } else if (types.contains('sublocality') ||
          types.contains('neighborhood') ||
          types.contains('sublocality_level_1')) {
        neighborhood ??= longName;
      } else if (types.contains('locality')) {
        locality = longName;
      }
    }

    final city = locality != null && locality.isNotEmpty
        ? locality
        : 'Cartagena';

    if (route != null && route.isNotEmpty) {
      final street = streetNumber != null ? '$route #$streetNumber' : route;
      if (neighborhood != null && neighborhood.isNotEmpty) {
        return '$street, $neighborhood, $city';
      }
      return '$street, $city';
    }

    if (neighborhood != null && neighborhood.isNotEmpty) {
      return '$neighborhood, $city';
    }

    return null;
  }

  static String _cleanFormattedAddress(String raw) {
    // Quita país redundante "Colombia" o códigos postales largos para una visualización limpia
    var cleaned = raw
        .replaceAll(
          RegExp(r',?\s*Bolívar,?\s*Colombia', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r',?\s*Colombia', caseSensitive: false), '')
        .replaceAll(
          RegExp(r'Cartagena de Indias', caseSensitive: false),
          'Cartagena',
        )
        .trim();
    if (cleaned.endsWith(',')) {
      cleaned = cleaned.substring(0, cleaned.length - 1).trim();
    }
    if (!cleaned.toLowerCase().contains('cartagena')) {
      cleaned = '$cleaned, Cartagena';
    }
    return cleaned;
  }

  @visibleForTesting
  void clearCache() {
    _reverseCache.clear();
    _forwardCache.clear();
    _routeCache.clear();
    _detourCache.clear();
  }
}
