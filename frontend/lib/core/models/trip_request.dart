import 'package:flutter/foundation.dart';

import 'initials.dart';
import 'trip_status.dart';

class TripRequestStop {
  const TripRequestStop({
    required this.seats,
    required this.placeType,
    required this.addressText,
    this.stopSequence,
  });

  factory TripRequestStop.fromJson(Map<String, dynamic> json) => TripRequestStop(
        seats: json['seats'] as int? ?? 1,
        placeType: json['place_type'] as String? ?? 'door',
        addressText: json['address_text'] as String? ?? '',
        stopSequence: json['stop_seq'] as int?,
      );

  final int seats;
  final String placeType;
  final String addressText;
  final int? stopSequence;
}

/// Solicitud de cupos que un pasajero envía sobre un viaje.
@immutable
class TripRequest {
  const TripRequest({
    required this.id,
    required this.tripId,
    required this.passengerId,
    this.seatCount = 1,
    required this.passengerName,
    required this.passengerPhone,
    required this.status,
    required this.createdAt,
    this.stops = const <TripRequestStop>[],
  });

  /// Identificador de la solicitud.
  final int id;

  /// Viaje al que pertenece.
  final int tripId;

  /// Persona que solicitó el cupo.
  final int passengerId;

  /// Personas que incluye esta reserva grupal, contando al titular.
  final int seatCount;

  /// Nombre y apellido, tal como lo arma el backend en `_to_response`.
  final String passengerName;

  /// Teléfono de contacto, o cadena vacía si el usuario no lo tiene.
  final String passengerPhone;

  /// Estado de la solicitud.
  final SeatRequestStatus status;

  /// Momento en que se creó.
  final DateTime createdAt;
  final List<TripRequestStop> stops;

  /// Lee la solicitud que devuelve la API.
  ///
  /// Tolera campos ausentes o nulos para que un payload incompleto no impida
  /// pintar la pantalla.
  factory TripRequest.fromJson(Map<String, dynamic> json) {
    final rawName = json['passenger_name'] as String?;
    return TripRequest(
      id: json['id'] as int? ?? 0,
      tripId: json['trip_id'] as int? ?? 0,
      passengerId: json['passenger_id'] as int? ?? 0,
      seatCount: json['seat_count'] as int? ?? 1,
      passengerName: rawName == null || rawName.trim().isEmpty
          ? 'Pasajero'
          : rawName.trim(),
      passengerPhone: json['passenger_phone'] as String? ?? '',
      status: SeatRequestStatus.fromWire(json['status'] as String?),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      stops: (json['stops'] as List? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(TripRequestStop.fromJson)
          .toList(growable: false),
    );
  }

  /// `true` mientras el conductor no ha respondido.
  bool get isPending => status.isPending;

  /// `true` cuando el cupo quedó confirmado.
  bool get isAccepted => status.isAccepted;

  /// Iniciales para el avatar: «Sebastián Ríos» → «SR».
  String get initials => initialsOf(passengerName);

  /// `true` si hay teléfono para mostrar.
  bool get hasPhone => passengerPhone.trim().isNotEmpty;

  TripRequest copyWith({SeatRequestStatus? status}) => TripRequest(
        id: id,
        tripId: tripId,
        passengerId: passengerId,
        seatCount: seatCount,
        passengerName: passengerName,
        passengerPhone: passengerPhone,
        status: status ?? this.status,
        createdAt: createdAt,
        stops: stops,
      );

  @override
  bool operator ==(Object other) =>
      other is TripRequest &&
      other.id == id &&
      other.tripId == tripId &&
      other.passengerId == passengerId &&
      other.seatCount == seatCount &&
      other.passengerName == passengerName &&
      other.passengerPhone == passengerPhone &&
      other.status == status;

  @override
  int get hashCode => Object.hash(
        id,
        tripId,
        passengerId,
        seatCount,
        passengerName,
        passengerPhone,
        status,
      );
}

/// Consultas sobre la lista de solicitudes de un viaje.
extension TripRequestList on List<TripRequest> {
  /// Solicitudes que el conductor todavía no ha respondido.
  ///
  /// Es la lista que alimenta la tarjeta «Solicitudes» del conductor.
  List<TripRequest> get pending =>
      where((request) => request.isPending).toList(growable: false);

  /// Solicitudes con cupo confirmado.
  ///
  /// Alimenta los nombres que ocupan cupo y el detalle de ruta.
  List<TripRequest> get accepted =>
      where((request) => request.isAccepted).toList(growable: false);
}
