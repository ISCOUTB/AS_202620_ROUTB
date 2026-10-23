/// Resultado de una consulta de geocodificación mostrado en el buscador.
class GeocodeResult {
  const GeocodeResult({
    required this.lat,
    required this.lng,
    required this.displayName,
    required this.source,
  });

  final double lat;
  final double lng;
  final String displayName;
  final String source;
}
