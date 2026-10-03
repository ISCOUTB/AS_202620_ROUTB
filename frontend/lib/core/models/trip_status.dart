/// Estado con el que el backend guarda un viaje.
///
/// La base de datos solo distingue activo y cancelado; la pantalla de
/// «En curso» se deriva de la hora de salida (ver `Trip.phase`).
enum TripStatus {
  active('active'),
  cancelled('cancelled');

  const TripStatus(this.wire);

  /// Valor con el que se serializa hacia la API.
  final String wire;

  /// `true` si los pasajeros todavía pueden ver y solicitar cupo.
  bool get isActive => this == TripStatus.active;

  /// Interpreta el valor de la API; cualquier cosa desconocida se trata como
  /// [TripStatus.active], que es el valor por defecto del backend.
  static TripStatus fromWire(String? raw) => raw == TripStatus.cancelled.wire
      ? TripStatus.cancelled
      : TripStatus.active;
}

/// Estado de una solicitud de cupo.
///
/// Los valores son los que usa `trip_requests.status`.
enum SeatRequestStatus {
  pending('pending'),
  accepted('accepted'),
  rejected('rejected');

  const SeatRequestStatus(this.wire);

  /// Valor con el que se serializa hacia la API.
  final String wire;

  /// `true` mientras el conductor no ha respondido.
  bool get isPending => this == SeatRequestStatus.pending;

  /// `true` cuando el cupo quedó confirmado.
  bool get isAccepted => this == SeatRequestStatus.accepted;

  /// `true` cuando el conductor la rechazó.
  bool get isRejected => this == SeatRequestStatus.rejected;

  /// Interpreta el valor de la API; cualquier cosa desconocida se trata como
  /// [SeatRequestStatus.pending].
  static SeatRequestStatus fromWire(String? raw) => switch (raw) {
    'accepted' => SeatRequestStatus.accepted,
    'rejected' => SeatRequestStatus.rejected,
    _ => SeatRequestStatus.pending,
  };
}

/// Fase de un viaje tal como se muestra en pantalla.
///
/// No viene de la API: [TripStatus.active] se reparte entre [scheduled] y
/// [onCourse] comparando la hora de salida con el reloj.
enum TripPhase {
  scheduled('Programada'),
  onCourse('En curso'),
  completed('Finalizado'),
  cancelled('Cancelada');

  const TripPhase(this.label);

  /// Texto de la píldora de estado.
  final String label;
}
