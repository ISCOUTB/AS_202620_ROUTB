import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class TripRequestData {
  final int id;
  final int tripId;
  final int passengerId;
  final String passengerName;
  final String passengerPhone;
  final String status;
  final DateTime createdAt;

  TripRequestData({
    required this.id,
    required this.tripId,
    required this.passengerId,
    required this.passengerName,
    required this.passengerPhone,
    required this.status,
    required this.createdAt,
  });

  factory TripRequestData.fromJson(Map<String, dynamic> json) {
    return TripRequestData(
      id: json['id'] as int,
      tripId: json['trip_id'] as int,
      passengerId: json['passenger_id'] as int,
      passengerName: (json['passenger_name'] as String?) ?? 'Pasajero',
      passengerPhone: (json['passenger_phone'] as String?) ?? '',
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class TripData {
  final int id;
  final String origin;
  final String destination;
  final int totalSeats;
  final int availableSeats;
  final String departureTime;
  final String status;
  final int? driverId;
  final String? driverName;
  final String? myRequestStatus;
  List<TripRequestData> requests;

  TripData({
    required this.id,
    required this.origin,
    required this.destination,
    required this.totalSeats,
    required this.availableSeats,
    required this.departureTime,
    required this.status,
    this.driverId,
    this.driverName,
    this.myRequestStatus,
    List<TripRequestData>? requests,
  }) : requests = requests ?? [];

  factory TripData.fromJson(Map<String, dynamic> json) {
    final rawRequests = json['requests'] as List<dynamic>?;

    return TripData(
      id: json['id'] as int,
      origin: json['origin'] as String,
      destination: json['destination'] as String,
      totalSeats: json['total_seats'] as int,
      availableSeats: json['available_seats'] as int,
      departureTime: (json['departure_time'] as String?) ?? '7:00 AM',
      status: (json['status'] as String?) ?? 'active',
      driverId: json['driver_id'] as int?,
      driverName: json['driver_name'] as String?,
      myRequestStatus: json['my_request_status'] as String?,
      requests: rawRequests != null
          ? rawRequests
              .map((req) => TripRequestData.fromJson(req as Map<String, dynamic>))
              .toList()
          : [],
    );
  }

  String get seatsText => '$availableSeats/$totalSeats cupos';
}

class TripApi {
  String get _baseUrl =>
      kIsWeb ? 'http://127.0.0.1:8000' : 'http://10.0.2.2:8000';

  Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('routb_access_token');
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<TripData>> getAvailableTrips({String? origin, String? destination}) async {
    final queryParams = <String, String>{};
    if (origin != null && origin.isNotEmpty) queryParams['origin'] = origin;
    if (destination != null && destination.isNotEmpty) queryParams['destination'] = destination;

    final uri = Uri.parse('$_baseUrl/trips/').replace(
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    final response = await http.get(uri, headers: await _headers());
    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List<dynamic>;
      return list.map((item) => TripData.fromJson(item as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<List<TripData>> getMyTrips() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/trips/my-trips'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List<dynamic>;
      final trips = list.map((item) => TripData.fromJson(item as Map<String, dynamic>)).toList();
      
      // Cargar las solicitudes de cada viaje del conductor
      for (final trip in trips) {
        trip.requests = await getTripRequests(trip.id);
      }
      return trips;
    }
    return [];
  }

  Future<TripData> createTrip({
    required String origin,
    required String destination,
    required String time,
    int totalSeats = 4,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/trips/'),
      headers: await _headers(),
      body: jsonEncode({
        'origin': origin.isEmpty ? 'Centro' : origin,
        'destination': destination.isEmpty ? 'UTB' : destination,
        'departure_time': time.isEmpty ? '7:00 AM' : time,
        'total_seats': totalSeats,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return TripData.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Error al publicar el viaje: ${response.statusCode}');
  }

  Future<bool> cancelTrip(int tripId) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/trips/$tripId/cancel'),
      headers: await _headers(),
    );
    return response.statusCode == 200;
  }

  Future<TripRequestData> requestSeat(int tripId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/requests/trips/$tripId'),
      headers: await _headers(),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return TripRequestData.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    throw Exception(body['detail'] ?? 'No se pudo reservar el cupo');
  }

  Future<List<TripRequestData>> getTripRequests(int tripId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/requests/trips/$tripId'),
        headers: await _headers(),
      );
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        return list
            .map((item) => TripRequestData.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<bool> acceptRequest(int requestId) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/requests/$requestId/accept'),
      headers: await _headers(),
    );
    return response.statusCode == 200;
  }

  Future<bool> rejectRequest(int requestId) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/requests/$requestId/reject'),
      headers: await _headers(),
    );
    return response.statusCode == 200;
  }
}

