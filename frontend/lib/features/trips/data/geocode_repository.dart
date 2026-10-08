import '../../../core/network/api_client.dart';

/// Resultado de una consulta de geocodificación.
class GeocodeResult {
  const GeocodeResult({
    required this.lat,
    required this.lng,
    required this.displayName,
    required this.source,
  });

  factory GeocodeResult.fromJson(Map<String, dynamic> json) {
    return GeocodeResult(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      displayName: (json['display_name'] as String?)?.trim() ?? '',
      source: (json['source'] as String?) ?? 'photon',
    );
  }

  final double lat;
  final double lng;
  final String displayName;
  final String source;
}

/// Repositorio de acceso al servicio de geocodificación (`GET /geocode/search`).
class GeocodeRepository {
  GeocodeRepository(this._api);

  final ApiClient _api;

  /// Busca una dirección en texto libre mediante Photon / Nominatim con caché en servidor.
  Future<List<GeocodeResult>> search(String query) async {
    final clean = query.trim();
    if (clean.length < 2) return const [];

    final response = await _api.get(
      '/geocode/search',
      query: <String, String?>{'q': clean},
    );

    if (response is List) {
      return response
          .whereType<Map<String, dynamic>>()
          .map(GeocodeResult.fromJson)
          .toList(growable: false);
    }
    return const [];
  }
}
