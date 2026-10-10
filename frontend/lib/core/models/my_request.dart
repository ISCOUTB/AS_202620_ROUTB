import 'package:flutter/foundation.dart';

import '../constants/zones.dart';
import 'initials.dart';
import 'travel_time.dart';
import 'trip_status.dart';
import 'trip_schedule.dart';

/// Solicitud propia del pasajero con una foto del viaje.
///
/// Viene de `GET /requests/me`. El viaje viaja dentro porque el listado público
/// `GET /trips/` deja de devolverlo en cuanto se ocupa el último cupo, y ese es
/// justo el momento en que el pasajero más lo necesita.
@immutable
class MyRequest {
  const MyRequest({
    required this.id,
    required this.tripId,
    this.seatCount = 1,
    required this.status,
    required this.origin,
    required this.destination,
    required this.rawDeparture,
    required this.departure,
    this.departureDate,
    this.meetingPoint = 'Por coordinar',
    required this.totalSeats,
    required this.availableSeats,
    required this.tripStatus,
    required this.createdAt,
    this.driverName,
    this.driverPhone,
    this.canWithdraw = true,
  });

  /// Identificador de la solicitud, el que se usa para retirarla.
  final int id;

  /// Identificador del viaje.
  final int tripId;

  /// Personas incluidas en la reserva, contando al pasajero titular.
  final int seatCount;

  /// Estado de la solicitud: pendiente, confirmada o rechazada.
  final SeatRequestStatus status;

  /// Barrio o punto de partida.
  final String origin;

  /// Barrio o punto de llegada.
  final String destination;

  /// Hora de salida tal como viene de la API.
  final String rawDeparture;

  /// Hora de salida interpretada, o `null` si el texto no tiene formato válido.
  final TravelTime? departure;

  /// Día concreto de salida del viaje solicitado.
  final DateTime? departureDate;

  /// Punto de encuentro publicado por el conductor.
  final String meetingPoint;

  /// Cupos que ofrece el viaje.
  final int totalSeats;

  /// Cupos libres del viaje; una solicitud aceptada puede ocupar varios.
  final int availableSeats;

  /// Estado del viaje: activo o cancelado.
  final TripStatus tripStatus;

  /// Momento en que se envió la solicitud.
  final DateTime createdAt;

  /// Nombre del conductor, como lo arma el backend.
  final String? driverName;

  /// Teléfono del conductor, para poder localizarlo el día del viaje.
  final String? driverPhone;

  /// `false` si esta solicitud no se puede retirar desde la app.
  ///
  /// Pasa cuando el backend todavía no expone `DELETE /requests/{id}` y el
  /// viaje se dedujo de `GET /trips/` en vez de venir de `GET /requests/me`.
  final bool canWithdraw;

  /// Lee la solicitud que devuelve `GET /requests/me`.
  factory MyRequest.fromJson(Map<String, dynamic> json) {
    final rawDeparture = (json['departure_time'] as String?)?.trim() ?? '';
    return MyRequest(
      id: json['id'] as int? ?? 0,
      tripId: json['trip_id'] as int? ?? 0,
      seatCount: json['seat_count'] as int? ?? 1,
      status: SeatRequestStatus.fromWire(json['status'] as String?),
      origin: (json['origin'] as String?)?.trim() ?? '',
      destination: (json['destination'] as String?)?.trim() ?? '',
      rawDeparture: rawDeparture,
      departure: TravelTime.tryParse(rawDeparture),
      departureDate: DateTime.tryParse(json['departure_date'] as String? ?? ''),
      meetingPoint:
          (json['meeting_point'] as String?)?.trim().isNotEmpty == true
          ? (json['meeting_point'] as String).trim()
          : 'Por coordinar',
      totalSeats: json['total_seats'] as int? ?? 0,
      availableSeats: json['available_seats'] as int? ?? 0,
      tripStatus: TripStatus.fromWire(json['trip_status'] as String?),
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      driverName: (json['driver_name'] as String?)?.trim(),
      driverPhone: (json['driver_phone'] as String?)?.trim(),
    );
  }

  /// `true` mientras el conductor no ha respondido.
  bool get isPending => status.isPending;

  /// `true` cuando el cupo quedó confirmado.
  bool get isConfirmed => status.isAccepted;

  /// `true` si la solicitud sigue viva: en curso o en espera de respuesta.
  bool get isActive => isPending || isConfirmed;

  /// `true` cuando el viaje ya no sale, porque se canceló.
  bool get isOrphaned => !tripStatus.isActive;

  /// `true` cuando ya pasó el día y la duración estimada del viaje.
  bool get isPast {
    final date = departureDate;
    if (date == null) return false;
    final today = TripSchedule.dateOnly(DateTime.now());
    final scheduled = TripSchedule.dateOnly(date);
    if (scheduled.isBefore(today)) return true;
    if (scheduled.isAfter(today) || departure == null) return false;
    final duration = routeZone?.minutes ?? 30;
    return departure!.minutesUntil(DateTime.now()) < -duration;
  }

  /// Texto de la píldora de estado.
  String get statusLabel {
    if (isOrphaned) return 'Viaje cancelado';
    if (isPast) return 'Viaje finalizado';
    if (isConfirmed) return 'Cupo confirmado';
    if (isPending) return 'Solicitud enviada';
    if (status == SeatRequestStatus.cancelled) return 'Cancelada por otra aceptación';
    if (status == SeatRequestStatus.expired) return 'Solicitud vencida';
    return 'No aceptada';
  }

  /// Trayecto tal como se muestra: «Centro → UTB».
  String get routeLabel => '$origin → $destination';

  /// Hora de salida, con el texto original como respaldo.
  String get departureLabel => departure?.label ?? rawDeparture;

  String get departureDateLabel => departureDate == null
      ? 'Fecha por confirmar'
      : TripSchedule.dateLabel(departureDate!);

  /// Solo la hora sin indicador: `7:00`.
  String get departureClockLabel => departure?.clockLabel ?? rawDeparture;

  /// `AM` o `PM`, o cadena vacía si no se pudo interpretar la hora.
  String get departureMeridiem => departure?.meridiem ?? '';

  /// `true` si hay nombre de conductor que mostrar.
  bool get hasDriverName => (driverName ?? '').trim().isNotEmpty;

  /// `true` si hay teléfono para mostrar.
  bool get hasDriverPhone => (driverPhone ?? '').trim().isNotEmpty;

  /// Iniciales del conductor para el avatar.
  String get driverInitials => initialsOf(driverName ?? '');

  /// Zona conocida del trayecto, si el texto coincide con el catálogo.
  Zone? get routeZone => Zones.byName(origin) ?? Zones.byName(destination);

  /// Llegada estimada, calculada con los minutos del barrio del trayecto.
  TravelTime? get estimatedArrival {
    final start = departure;
    final zone = routeZone;
    if (start == null || zone == null) return null;
    return start.shifted(zone.minutes);
  }

  /// Copia con los campos indicados sustituidos.
  MyRequest copyWith({
    SeatRequestStatus? status,
    TripStatus? tripStatus,
    bool? canWithdraw,
  }) => MyRequest(
    id: id,
    tripId: tripId,
    seatCount: seatCount,
    status: status ?? this.status,
    origin: origin,
    destination: destination,
    rawDeparture: rawDeparture,
    departure: departure,
    departureDate: departureDate,
    meetingPoint: meetingPoint,
    totalSeats: totalSeats,
    availableSeats: availableSeats,
    tripStatus: tripStatus ?? this.tripStatus,
    createdAt: createdAt,
    driverName: driverName,
    driverPhone: driverPhone,
    canWithdraw: canWithdraw ?? this.canWithdraw,
  );

  @override
  bool operator ==(Object other) =>
      other is MyRequest &&
      other.id == id &&
      other.tripId == tripId &&
      other.status == status &&
      other.seatCount == seatCount;

  @override
  int get hashCode => Object.hash(id, tripId, seatCount, status);
}
