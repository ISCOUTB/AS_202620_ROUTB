import '../../../core/models/trip_suggestion.dart';
import '../../../core/network/api_client.dart';

/// Cliente del endpoint de sugerencias de viajes compatibles.
class MatchingRepository {
  const MatchingRepository(this._api);

  final ApiClient _api;

  Future<List<TripSuggestion>> suggestions({
    required String direction,
    required List<({double lat, double lng})> points,
    required DateTime date,
    required String time,
    required int seatCount,
    bool relaxed = false,
  }) async {
    final response = await _api.get(
      '/matching/suggestions',
      query: <String, String?>{
        'direction': direction,
        'points': points
            .map((point) => '${point.lat},${point.lng}')
            .join(';'),
        'date': '${date.year.toString().padLeft(4, '0')}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}',
        'time': time,
        'seat_count': '$seatCount',
        'relaxed': '$relaxed',
      },
    );
    if (response is! List) return const <TripSuggestion>[];
    return response
        .whereType<Map<String, dynamic>>()
        .map(TripSuggestion.fromJson)
        .toList(growable: false);
  }
}
