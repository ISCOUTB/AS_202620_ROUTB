import 'package:flutter/foundation.dart';

import '../../../core/models/trip.dart';
import '../../../core/models/trip_request.dart';

/// Estado de la pantalla del conductor.
enum DriverStatus { loading, ready, failed }

/// Lo que la pantalla del conductor necesita saber en cada momento.
@immutable
class DriverState {
  const DriverState({
    required this.status,
    this.trips = const <Trip>[],
    this.selected,
    this.errorMessage,
  });

  /// En qué punto está la carga.
  final DriverStatus status;

  /// Rutas publicadas por el conductor, de la más reciente a la más antigua.
  final List<Trip> trips;

  /// Ruta que se está mostrando en el hero, el mapa y el contador de cupos.
  ///
  /// El diseño permite tocar una tarjeta de «Mis rutas» para que el hero la
  /// tome. Cuando el conductor no tiene ninguna, es `null`.
  final Trip? selected;

  /// Mensaje del último fallo, para el estado de error.
  final String? errorMessage;

  /// `true` mientras no se ha fijado una ruta seleccionada.
  bool get hasTrips => trips.isNotEmpty;

  /// `true` si la ruta seleccionada pertenece a la lista.
  bool get selectionIsValid =>
      selected != null && trips.any((trip) => trip.id == selected!.id);

  /// Rutas con al menos una solicitud sin responder.
  List<Trip> get tripsWithPendingRequests => trips
      .where((trip) => trip.requests.pending.isNotEmpty)
      .toList(growable: false);

  /// Total de solicitudes sin responder, para el contador de la tarjeta.
  int get pendingRequestCount => trips.fold<int>(
        0,
        (total, trip) => total + trip.requests.pending.length,
      );

  /// Copia con los campos indicados sustituidos.
  ///
  /// Si la ruta seleccionada deja de estar en [trips], la selección se olvida,
  /// de modo que el hero nunca muestra algo que se canceló.
  DriverState copyWith({
    DriverStatus? status,
    List<Trip>? trips,
    Trip? selected,
    String? errorMessage,
    bool clearError = false,
  }) {
    final nextTrips = trips ?? this.trips;
    final requested = selected ?? this.selected;
    final stillPresent =
        requested != null && nextTrips.any((trip) => trip.id == requested.id);

    return DriverState(
      status: status ?? this.status,
      trips: nextTrips,
      selected: stillPresent ? requested : null,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}