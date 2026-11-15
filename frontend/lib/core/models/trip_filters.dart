import 'trip.dart';

/// Franja horaria con la que el pasajero acota el listado de viajes.
///
/// El filtro se aplica en el cliente sobre los viajes que ya se descargaron
/// para la fecha elegida: no cambia el contrato de `GET /trips/` ni la búsqueda
/// por cercanía del backend.
enum TripTimeRange {
  any('Cualquier hora'),
  morning('Mañana'),
  midday('Mediodía'),
  afternoon('Tarde');

  const TripTimeRange(this.label);

  /// Texto que se muestra en el selector.
  final String label;

  /// Texto corto para el selector compacto del hero.
  String get shortLabel => switch (this) {
    TripTimeRange.any => 'Todas',
    TripTimeRange.morning => 'Mañana',
    TripTimeRange.midday => 'Mediodía',
    TripTimeRange.afternoon => 'Tarde',
  };

  /// `true` si la hora de salida cae en la franja.
  ///
  /// Un viaje sin hora interpretable solo aparece en «Cualquier hora»: no se
  /// puede asegurar que pertenezca a una franja concreta.
  bool includes(Trip trip) {
    if (this == TripTimeRange.any) return true;
    final departure = trip.departure;
    if (departure == null) return false;

    return switch (this) {
      TripTimeRange.any => true,
      TripTimeRange.morning => departure.minutes < 12 * 60,
      TripTimeRange.midday =>
        departure.minutes >= 12 * 60 && departure.minutes < 15 * 60,
      TripTimeRange.afternoon => departure.minutes >= 15 * 60,
    };
  }
}

/// Orden con el que se presentan los resultados de búsqueda.
enum TripSortOrder {
  earliest('Más temprano'),
  mostSeats('Más cupos libres'),
  bestMatch('Mejor coincidencia');

  const TripSortOrder(this.label);

  /// Texto que se muestra en el selector y en el menú.
  final String label;
}

/// Filtra por franja horaria y ordena según la preferencia del pasajero.
///
/// El orden «Mejor coincidencia» es una heurística local: prioriza la
/// proporción de cupos libres del viaje y, en empate, la salida más temprana.
/// Para la búsqueda puerta a puerta existe `score` del backend; este listado no
/// lo recibe, así que no se inventa una llamada nueva.
List<Trip> filterAndSortTrips(
  List<Trip> trips, {
  TripTimeRange range = TripTimeRange.any,
  TripSortOrder order = TripSortOrder.earliest,
}) {
  final filtered = range == TripTimeRange.any
      ? List<Trip>.of(trips)
      : trips.where(range.includes).toList();
  filtered.sort((a, b) => _compare(a, b, order));
  return filtered;
}

int _compare(Trip a, Trip b, TripSortOrder order) {
  switch (order) {
    case TripSortOrder.earliest:
      final byTime = _compareDeparture(a, b);
      return byTime != 0
          ? byTime
          : b.availableSeats.compareTo(a.availableSeats);
    case TripSortOrder.mostSeats:
      final bySeats = b.availableSeats.compareTo(a.availableSeats);
      return bySeats != 0 ? bySeats : _compareDeparture(a, b);
    case TripSortOrder.bestMatch:
      final byRatio = _seatRatio(b).compareTo(_seatRatio(a));
      return byRatio != 0 ? byRatio : _compareDeparture(a, b);
  }
}

/// Los viajes sin hora interpretable quedan al final.
int _compareDeparture(Trip a, Trip b) {
  final left = a.departure;
  final right = b.departure;
  if (left == null && right == null) return 0;
  if (left == null) return 1;
  if (right == null) return -1;
  return left.compareTo(right);
}

double _seatRatio(Trip trip) =>
    trip.totalSeats <= 0 ? 0 : trip.availableSeats / trip.totalSeats;
