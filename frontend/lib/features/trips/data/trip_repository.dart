import '../../../core/models/my_request.dart';
import '../../../core/models/trip.dart';
import '../../../core/models/trip_request.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

/// Acceso a los viajes, sin importar quién los pide.
///
/// Lo comparten el modo pasajero (que lee los disponibles y solicita cupos) y el
/// modo conductor (que lee los suyos, publica, cancela y responde solicitudes).
class TripRepository {
  TripRepository(this._api);

  final ApiClient _api;

  /// `GET /trips/`
  ///
  /// El backend solo devuelve los viajes activos y con cupo libre. Si hay
  /// token, cada viaje incluye `my_request_status`.
  Future<List<Trip>> listAvailable({
    String? origin,
    String? destination,
  }) async {
    final response = await _api.get(
      '/trips/',
      query: <String, String?>{
        'origin': origin?.trim(),
        'destination': destination?.trim(),
      },
    );
    return _asTrips(response);
  }

  /// `GET /trips/my-trips`
  ///
  /// Solo trae los viajes activos del conductor; las canceladas no aparecen,
  /// así que cancelar una ruta es definitivo desde el punto de vista de la app.
  Future<List<Trip>> listMine() async {
    final response = await _api.get('/trips/my-trips');
    return _asTrips(response);
  }

  /// `POST /trips/`
  Future<Trip> publish({
    required String origin,
    required String destination,
    required String departureTime,
    required int seats,
  }) async {
    final response = await _api.post(
      '/trips/',
      body: <String, Object?>{
        'origin': origin,
        'destination': destination,
        'departure_time': departureTime,
        'total_seats': seats.clamp(1, 4),
      },
    );
    return Trip.fromJson(_asMap(response));
  }

  /// `PATCH /trips/{id}/cancel`
  Future<Trip> cancel(int tripId) async {
    final response = await _api.patch('/trips/$tripId/cancel');
    return Trip.fromJson(_asMap(response));
  }

  /// `GET /requests/trips/{id}`
  Future<List<TripRequest>> listRequests(int tripId) async {
    final response = await _api.get('/requests/trips/$tripId');
    return _asRequests(response);
  }

  /// `POST /requests/trips/{id}`
  Future<TripRequest> requestSeat(int tripId) async {
    final response = await _api.post('/requests/trips/$tripId');
    return TripRequest.fromJson(_asMap(response));
  }

  /// `PATCH /requests/{id}/accept`
  Future<TripRequest> accept(int requestId) async {
    final response = await _api.patch('/requests/$requestId/accept');
    return TripRequest.fromJson(_asMap(response));
  }

  /// `PATCH /requests/{id}/reject`
  Future<TripRequest> reject(int requestId) async {
    final response = await _api.patch('/requests/$requestId/reject');
    return TripRequest.fromJson(_asMap(response));
  }

  /// `GET /requests/me`
  ///
  /// Solicitudes de la persona que entra, con los datos de su viaje. Es la
  /// única vía para seguir viendo un viaje propio cuando ya no sale en
  /// `GET /trips/`, que filtra los viajes sin cupo libre.
  ///
  /// Si el backend todavía no tiene el endpoint devuelve 404 y se recurre a
  /// derivarlo de `GET /trips/`. Ese camino es peor: no sobrevive a que el viaje
  /// se llene y no trae el identificador de la solicitud, así que esas
  /// entradas salen con [MyRequest.canWithdraw] en `false`.
  Future<List<MyRequest>> myRequests() async {
    try {
      final response = await _api.get('/requests/me');
      return _asMyRequests(response);
    } on ApiException catch (error) {
      if (!error.isNotFound) rethrow;
      return _myRequestsFromTrips();
    }
  }

  /// Respaldo para un backend sin `GET /requests/me`.
  ///
  /// `GET /trips/` ya incluye `my_request_status` cuando hay token, así que se
  /// puede montar la misma pantalla aunque el viaje siga teniendo cupo. En
  /// cuanto se llena, esta vía no ve nada, que es justo el caso que motivó el
  /// endpoint.
  Future<List<MyRequest>> _myRequestsFromTrips() async {
    final trips = await listAvailable();
    return <MyRequest>[
      for (final trip in trips)
        if (trip.myRequestStatus != null &&
            (trip.myRequestStatus!.isPending || trip.myRequestStatus!.isAccepted))
          MyRequest(
            // Sin endpoint no hay forma de saber el id de la solicitud, y sin id
            // no hay retiro.
            id: 0,
            tripId: trip.id,
            status: trip.myRequestStatus!,
            origin: trip.origin,
            destination: trip.destination,
            rawDeparture: trip.rawDeparture,
            departure: trip.departure,
            totalSeats: trip.totalSeats,
            availableSeats: trip.availableSeats,
            tripStatus: trip.status,
            createdAt: DateTime.now(),
            driverName: trip.driverName,
            canWithdraw: false,
          ),
    ];
  }

  /// `DELETE /requests/{id}`
  ///
  /// Retira la solicitud y devuelve el cupo si estaba confirmada. La borra de
  /// verdad, no la marca, para que se pueda volver a pedir en el mismo viaje.
  Future<void> withdrawRequest(int requestId) async {
    await _api.delete('/requests/$requestId');
  }

  static List<MyRequest> _asMyRequests(Object? response) {
    if (response is! List) return const <MyRequest>[];
    return response
        .whereType<Map<String, dynamic>>()
        .map(MyRequest.fromJson)
        .toList(growable: false);
  }

  static List<Trip> _asTrips(Object? response) {
    if (response is! List) return const <Trip>[];
    return response
        .whereType<Map<String, dynamic>>()
        .map(Trip.fromJson)
        .toList(growable: false);
  }

  static List<TripRequest> _asRequests(Object? response) {
    if (response is! List) return const <TripRequest>[];
    return response
        .whereType<Map<String, dynamic>>()
        .map(TripRequest.fromJson)
        .toList(growable: false);
  }

  static Map<String, dynamic> _asMap(Object? response) {
    if (response is Map<String, dynamic>) return response;
    throw StateError('El backend no devolvió un objeto: $response');
  }
}