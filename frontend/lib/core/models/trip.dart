import 'package:flutter/foundation.dart';

import '../constants/zones.dart';
import 'initials.dart';
import 'trip_schedule.dart';
import 'travel_time.dart';
import 'trip_request.dart';
import 'trip_status.dart';

/// Un viaje publicado por un conductor.
///
/// Es un objeto inmutable: cuando el conductor acepta o rechaza una solicitud
/// se crea una copia con [copyWith], en lugar de mutar la lista en sitio.
@immutable
class Trip {
  const Trip({
    required this.id,
    required this.origin,
    required this.destination,
    required this.totalSeats,
    required this.availableSeats,
    required this.rawDeparture,
    required this.departure,
    this.departureDate,
    this.meetingPoint = 'Por coordinar',
    required this.status,
    required this.requests,
    this.driverId,
    this.driverName,
    this.myRequestStatus,
    this.direction,
  });

  /// Identificador del viaje.
  final int id;

  /// Barrio o punto de partida.
  final String origin;

  /// Barrio o punto de llegada.
  final String destination;

  /// Cupos que ofrece el conductor, de 1 a 4.
  final int totalSeats;

  /// Cupos que quedan disponibles. Lo mantiene el backend con control atómico.
  final int availableSeats;

  /// Texto de hora tal como viene de la API, para mostrarlo si no se puede
  /// interpretar.
  final String rawDeparture;

  /// Hora de salida interpretada, o `null` si el texto no tiene formato válido.
  final TravelTime? departure;

  /// Día concreto de salida de esta publicación.
  final DateTime? departureDate;

  /// Referencia donde conductor y grupo se encuentran.
  final String meetingPoint;

  /// Estado persistido.
  final TripStatus status;

  /// Conductor dueño del viaje.
  final int? driverId;

  /// Nombre del conductor, como lo arma el backend con nombre y apellido.
  final String? driverName;

  /// Estado de la solicitud de la persona que está mirando, o `null` si no ha
  /// solicitado cupo. Solo lo devuelve `GET /trips/` cuando hay token.
  final SeatRequestStatus? myRequestStatus;

  /// Sentido geográfico; nulo identifica viajes legados.
  final String? direction;

  /// Solicitudes del viaje. `GET /trips/my-trips` las incluye; para pasajero
  /// llega vacía.
  final List<TripRequest> requests;

  /// Lee el viaje que devuelve la API.
  factory Trip.fromJson(Map<String, dynamic> json) {
    final rawRequests = json['requests'] as List<dynamic>?;
    final rawDeparture = (json['departure_time'] as String?)?.trim() ?? '';
    final rawMyRequest = json['my_request_status'] as String?;

    return Trip(
      id: json['id'] as int? ?? 0,
      origin: (json['origin'] as String?)?.trim().isNotEmpty == true
          ? (json['origin'] as String).trim()
          : 'Centro',
      destination: (json['destination'] as String?)?.trim().isNotEmpty == true
          ? (json['destination'] as String).trim()
          : 'UTB',
      totalSeats: (json['total_seats'] as int?)?.clamp(1, 4) ?? 4,
      availableSeats: (json['available_seats'] as int?) ?? 0,
      rawDeparture: rawDeparture,
      departure: TravelTime.tryParse(rawDeparture),
      departureDate: DateTime.tryParse(json['departure_date'] as String? ?? ''),
      meetingPoint:
          (json['meeting_point'] as String?)?.trim().isNotEmpty == true
          ? (json['meeting_point'] as String).trim()
          : 'Por coordinar',
      status: TripStatus.fromWire(json['status'] as String?),
      driverId: json['driver_id'] as int?,
      driverName: (json['driver_name'] as String?)?.trim(),
      // Sin el campo no hay solicitud propia: hay que distinguir «no ha
      // solicitado» de «solicitó y está en espera».
      myRequestStatus: rawMyRequest == null
          ? null
          : SeatRequestStatus.fromWire(rawMyRequest),
      direction: json['direction'] as String?,
      requests: rawRequests == null
          ? const <TripRequest>[]
          : rawRequests
                .whereType<Map<String, dynamic>>()
                .map(TripRequest.fromJson)
                .toList(growable: false),
    );
  }

  // --- Cupos ---------------------------------------------------------------

  /// Cupos ya ocupados.
  int get takenSeats => (totalSeats - availableSeats).clamp(0, totalSeats);

  /// `true` cuando no queda ningún cupo.
  bool get isFull => availableSeats <= 0;

  /// `true` cuando el conductor todavía puede recibir solicitudes.
  bool get acceptsRequests => status.isActive && !isFull;

  // --- Lugares ---------------------------------------------------------------

  /// Zona conocida del origen, si el texto coincide con un barrio del catálogo.
  Zone? get originZone => Zones.byName(origin);

  /// Zona conocida del destino, si el texto coincide con un barrio del
  /// catálogo o con la UTB.
  Zone? get destinationZone => Zones.byName(destination);

  /// Barrio que determina la duración del trayecto: el que sea conocido entre
  /// origen y destino. La UTB no aporta distancia porque es el extremo fijo.
  Zone? get routeZone => originZone ?? destinationZone;

  /// `true` si el trayecto termina o empieza en la UTB.
  bool get touchesCampus =>
      Zones.isCampus(origin) || Zones.isCampus(destination);

  /// Texto del trayecto tal como lo muestra el conductor: «Centro → UTB».
  String get routeLabel => '$origin → $destination';

  String get departureDateLabel => departureDate == null
      ? 'Fecha por confirmar'
      : TripSchedule.dateLabel(departureDate!);

  // --- Horarios ---------------------------------------------------------------

  /// Hora de salida para mostrar: la interpretada o, si no se pudo leer, el
  /// texto original de la API.
  String get departureLabel => departure?.label ?? rawDeparture;

  /// Solo la hora sin indicador: `7:00`.
  String get departureClockLabel => departure?.clockLabel ?? rawDeparture;

  /// `AM` o `PM`, o cadena vacía si la hora no se pudo interpretar.
  String get departureMeridiem => departure?.meridiem ?? '';

  /// Llegada estimada, calculada con la duración del barrio del trayecto.
  ///
  /// Es una estimación del cliente a partir de una tabla fija de minutos por
  /// barrio; el backend no guarda ni calcula tiempos de recorrido.
  TravelTime? get estimatedArrival {
    final start = departure;
    final zone = routeZone;
    if (start == null || zone == null) return null;
    return start.shifted(zone.minutes);
  }

  /// Fase del viaje en el instante [now].
  ///
  /// La fecha viene del backend; la fase «En curso» se estima con la duración
  /// por zona porque ROUTB todavía no recibe la posición real del vehículo.
  TripPhase phaseAt(DateTime now) {
    if (!status.isActive) return TripPhase.cancelled;

    final scheduledDate = departureDate;
    if (scheduledDate != null) {
      final date = TripSchedule.dateOnly(scheduledDate);
      final today = TripSchedule.dateOnly(now);
      if (date.isAfter(today)) return TripPhase.scheduled;
      if (date.isBefore(today)) return TripPhase.completed;
    }

    final start = departure;
    if (start == null) return TripPhase.scheduled;

    final zone = routeZone;
    final window = zone?.minutes ?? 30;

    // `minutesUntil` da la distancia hasta la hora de salida: es negativa
    // cuando el viaje ya salió. «En curso» es la ventana entre que sale y que
    // termina de recorrer el barrio.
    final remaining = start.minutesUntil(now);
    if (remaining <= 0 && remaining >= -window) return TripPhase.onCourse;
    return remaining < -window && departureDate != null
        ? TripPhase.completed
        : TripPhase.scheduled;
  }

  /// `true` si el viaje sale dentro de [window] y todavía tiene cupo.
  ///
  /// Criterio de la insignia «Nuevo» para los viajes que salen pronto hoy.
  bool isImminent(
    DateTime now, {
    Duration window = const Duration(minutes: 90),
  }) {
    if (!status.isActive || isFull) return false;
    if (departureDate != null &&
        !TripSchedule.dateOnly(departureDate!)
            .isAtSameMomentAs(TripSchedule.dateOnly(now))) {
      return false;
    }
    return departure?.isWithin(now, window: window) ?? false;
  }

  // --- Solicitud propia --------------------------------------------------------

  /// Estado de la solicitud de la persona que está mirando.
  SeatRequestState get bookingState {
    if (myRequestStatus?.isAccepted ?? false) return SeatRequestState.confirmed;
    if (myRequestStatus?.isPending ?? false) return SeatRequestState.requested;
    if (!status.isActive) return SeatRequestState.unavailable;
    if (isFull) return SeatRequestState.full;
    return SeatRequestState.available;
  }

  // --- Conductores --------------------------------------------------------------

  /// Iniciales del conductor para el avatar del pasajero.
  String get driverInitials => initialsOf(driverName ?? '');

  /// `true` si hay nombre de conductor que mostrar.
  bool get hasDriverName => (driverName ?? '').trim().isNotEmpty;

  /// Copia con los campos indicados sustituidos.
  Trip copyWith({
    int? availableSeats,
    DateTime? departureDate,
    String? meetingPoint,
    TripStatus? status,
    SeatRequestStatus? myRequestStatus,
    String? direction,
    List<TripRequest>? requests,
  }) => Trip(
    id: id,
    origin: origin,
    destination: destination,
    totalSeats: totalSeats,
    availableSeats: availableSeats ?? this.availableSeats,
    rawDeparture: rawDeparture,
    departure: departure,
    departureDate: departureDate ?? this.departureDate,
    meetingPoint: meetingPoint ?? this.meetingPoint,
    status: status ?? this.status,
    driverId: driverId,
    driverName: driverName,
    myRequestStatus: myRequestStatus ?? this.myRequestStatus,
    direction: direction ?? this.direction,
    requests: requests ?? this.requests,
  );

  @override
  bool operator ==(Object other) =>
      other is Trip &&
      other.id == id &&
      other.origin == origin &&
      other.destination == destination &&
      other.totalSeats == totalSeats &&
      other.availableSeats == availableSeats &&
      other.rawDeparture == rawDeparture &&
      other.departureDate == departureDate &&
      other.meetingPoint == meetingPoint &&
      other.status == status &&
      other.driverId == driverId &&
      other.driverName == driverName &&
      other.myRequestStatus == myRequestStatus;

  @override
  int get hashCode => Object.hash(
    id,
    origin,
    destination,
    totalSeats,
    availableSeats,
    rawDeparture,
    departureDate,
    meetingPoint,
    status,
    driverId,
    driverName,
    myRequestStatus,
  );
}

/// Estado del botón de reserva en la tarjeta de un viaje.
enum SeatRequestState {
  /// Se puede solicitar.
  available,

  /// Ya se envió y el conductor no ha respondido.
  ///
  /// La API no tiene endpoint para retirar una solicitud, así que el botón
  /// queda informativo.
  requested,

  /// El conductor confirmó el cupo.
  confirmed,

  /// El viaje ya no está activo.
  unavailable,

  /// No quedan cupos.
  full;

  /// `true` si el botón acepta pulsaciones.
  bool get isActionable => this == SeatRequestState.available;
}
