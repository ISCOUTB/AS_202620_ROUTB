/// Viaje que el backend recomienda para una solicitud puerta a puerta.
class TripSuggestion {
  const TripSuggestion({
    required this.tripId,
    required this.driverName,
    required this.origin,
    required this.destination,
    required this.direction,
    required this.departureDate,
    required this.departureTime,
    required this.availableSeats,
    required this.etaPickup,
    required this.detourMinutes,
    required this.walkDistanceM,
    required this.score,
    required this.degraded,
  });

  factory TripSuggestion.fromJson(Map<String, dynamic> json) => TripSuggestion(
        tripId: json['trip_id'] as int,
        driverName: json['driver_name'] as String? ?? 'Conductor',
        origin: json['origin'] as String? ?? '',
        destination: json['destination'] as String? ?? '',
        direction: json['direction'] as String? ?? 'to_campus',
        departureDate: DateTime.parse(json['departure_date'] as String),
        departureTime: json['departure_time'] as String? ?? '',
        availableSeats: json['available_seats'] as int? ?? 0,
        etaPickup: DateTime.tryParse(json['eta_pickup'] as String? ?? ''),
        detourMinutes: (json['detour_minutes'] as num? ?? 0).toDouble(),
        walkDistanceM: (json['walk_distance_m'] as num? ?? 0).toDouble(),
        score: (json['score'] as num? ?? 1).toDouble(),
        degraded: json['degraded'] as bool? ?? false,
      );

  final int tripId;
  final String driverName;
  final String origin;
  final String destination;
  final String direction;
  final DateTime departureDate;
  final String departureTime;
  final int availableSeats;
  final DateTime? etaPickup;
  final double detourMinutes;
  final double walkDistanceM;
  final double score;
  final bool degraded;
}
