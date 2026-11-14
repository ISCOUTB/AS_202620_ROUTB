import 'package:latlong2/latlong.dart';

/// Lee la lista `route_points` que devuelve la API.
///
/// Cada punto llega como `{"lat": ..., "lng": ...}`. Se ignoran los elementos
/// incompletos o con valores no numéricos para que un payload parcial no rompa
/// la pantalla.
List<LatLng> routePointsFromJson(Object? raw) {
  if (raw is! List) return const <LatLng>[];
  final points = <LatLng>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final lat = _asDouble(item['lat']);
    final lng = _asDouble(item['lng']);
    if (lat == null || lng == null) continue;
    points.add(LatLng(lat, lng));
  }
  return List<LatLng>.unmodifiable(points);
}

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}
