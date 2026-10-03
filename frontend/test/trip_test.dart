import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/models/initials.dart';
import 'package:frontend/core/models/trip.dart';
import 'package:frontend/core/models/trip_request.dart';
import 'package:frontend/core/models/trip_status.dart';
import 'package:frontend/core/models/user_role.dart';

Map<String, dynamic> tripPayload({
  int id = 1,
  String origin = 'Centro',
  String destination = 'UTB',
  int totalSeats = 4,
  int availableSeats = 3,
  String departure = '7:00 AM',
  String status = 'active',
  String? driverName = 'Enzo Fernández',
  String? myRequestStatus,
  List<Map<String, dynamic>> requests = const <Map<String, dynamic>>[],
}) => <String, dynamic>{
  'id': id,
  'origin': origin,
  'destination': destination,
  'total_seats': totalSeats,
  'available_seats': availableSeats,
  'departure_time': departure,
  'status': status,
  'driver_id': 9,
  'driver_name': driverName,
  'my_request_status': myRequestStatus,
  'requests': requests,
};

void main() {
  group('initialsOf', () {
    test('toma la inicial del nombre y la del apellido', () {
      expect(initialsOf('Sebastián Ríos'), 'SR');
      expect(initialsOf('Enzo Fernández'), 'EF');
      expect(initialsOf('Ana María Restrepo'), 'AR');
    });

    test('con un solo nombre usa las dos primeras letras', () {
      expect(initialsOf('Ana'), 'AN');
      expect(initialsOf('Bo'), 'BO');
    });

    test('nunca devuelve una cadena vacía', () {
      expect(initialsOf(''), '?');
      expect(initialsOf('   '), '?');
    });
  });

  group('Trip: cupos', () {
    test('calcula los ocupados a partir de los libres', () {
      expect(Trip.fromJson(tripPayload(availableSeats: 2)).takenSeats, 2);
      expect(Trip.fromJson(tripPayload(availableSeats: 0)).takenSeats, 4);
      expect(Trip.fromJson(tripPayload(availableSeats: 0)).isFull, isTrue);
      expect(
        Trip.fromJson(tripPayload(availableSeats: 3)).acceptsRequests,
        isTrue,
      );
    });

    test('una ruta cancelada ya no acepta solicitudes', () {
      final trip = Trip.fromJson(tripPayload(status: 'cancelled'));
      expect(trip.status.isActive, isFalse);
      expect(trip.acceptsRequests, isFalse);
    });
  });

  group('Trip: horarios', () {
    test('usa la hora interpretada cuando se puede', () {
      final trip = Trip.fromJson(tripPayload(departure: '7:00 AM'));
      expect(trip.departure?.label, '7:00 AM');
      expect(trip.departureLabel, '7:00 AM');
      expect(trip.departureClockLabel, '7:00');
      expect(trip.departureMeridiem, 'AM');
    });

    test('cae al texto original si la hora no tiene formato válido', () {
      final trip = Trip.fromJson(tripPayload(departure: 'cuando pueda'));
      expect(trip.departure, isNull);
      expect(trip.departureLabel, 'cuando pueda');
      expect(trip.departureMeridiem, isEmpty);
    });

    test('estima la llegada con los minutos del barrio', () {
      // Centro está a 25 minutos de la UTB.
      expect(
        Trip.fromJson(tripPayload(departure: '7:00 AM'))
            .estimatedArrival
            ?.label,
        '7:25 AM',
      );
      // Turbaco está a 20.
      expect(
        Trip.fromJson(
          tripPayload(
            origin: 'Turbaco',
            destination: 'UTB',
            departure: '6:00 PM',
          ),
        ).estimatedArrival?.label,
        '6:20 PM',
      );
    });

    test('no estima llegada si ningún extremo está en el catálogo', () {
      final trip = Trip.fromJson(
        tripPayload(origin: 'Calle 45', destination: 'Parque Residencial'),
      );
      expect(trip.estimatedArrival, isNull);
    });
  });

  group('Trip: fase', () {
    final trip = Trip.fromJson(tripPayload(departure: '7:00 AM'));

    test('«Programada» antes de la hora de salida', () {
      expect(trip.phaseAt(DateTime(2026, 10, 1, 6, 30)), TripPhase.scheduled);
    });

    test('«En curso» durante el trayecto', () {
      expect(trip.phaseAt(DateTime(2026, 10, 1, 7, 10)), TripPhase.onCourse);
    });

    test('vuelve a «Programada» cuando la hora ya pasó', () {
      // La API guarda la hora sin fecha, así que el día siguiente la misma hora
      // vuelve a estar por delante.
      expect(trip.phaseAt(DateTime(2026, 10, 2, 7, 10)), TripPhase.onCourse);
      expect(trip.phaseAt(DateTime(2026, 10, 1, 23, 0)), TripPhase.scheduled);
    });

    test('una ruta cancelada nunca está en curso', () {
      final cancelada = Trip.fromJson(tripPayload(status: 'cancelled'));
      expect(
        cancelada.phaseAt(DateTime(2026, 10, 1, 7, 10)),
        TripPhase.cancelled,
      );
    });

    test('una hora ilegible deja el viaje programado', () {
      final raro = Trip.fromJson(tripPayload(departure: 'mañana'));
      expect(raro.phaseAt(DateTime(2026, 10, 1, 7, 10)), TripPhase.scheduled);
    });
  });

  group('Trip: insignia «Nuevo»', () {
    final now = DateTime(2026, 10, 1, 6, 30);

    test('marca las salidas próximas con cupo libre', () {
      expect(
        Trip.fromJson(tripPayload(departure: '7:00 AM', availableSeats: 2))
            .isImminent(now),
        isTrue,
      );
    });

    test('no marca las salidas lejanas', () {
      expect(
        Trip.fromJson(tripPayload(departure: '9:00 AM')).isImminent(now),
        isFalse,
      );
    });

    test('no marca un viaje lleno ni uno cancelado', () {
      expect(
        Trip.fromJson(tripPayload(departure: '7:00 AM', availableSeats: 0))
            .isImminent(now),
        isFalse,
      );
      expect(
        Trip.fromJson(tripPayload(departure: '7:00 AM', status: 'cancelled'))
            .isImminent(now),
        isFalse,
      );
    });
  });

  group('Trip: estado de la reserva', () {
    test('cada my_request_status produce un estado de botón', () {
      expect(
        Trip.fromJson(tripPayload()).bookingState,
        SeatRequestState.available,
      );
      expect(
        Trip.fromJson(tripPayload(myRequestStatus: 'pending')).bookingState,
        SeatRequestState.requested,
      );
      expect(
        Trip.fromJson(tripPayload(myRequestStatus: 'accepted')).bookingState,
        SeatRequestState.confirmed,
      );
      expect(
        Trip.fromJson(tripPayload(availableSeats: 0)).bookingState,
        SeatRequestState.full,
      );
      expect(
        Trip.fromJson(tripPayload(status: 'cancelled')).bookingState,
        SeatRequestState.unavailable,
      );
    });

    test('solo el estado disponible admite pulsación', () {
      expect(SeatRequestState.available.isActionable, isTrue);
      expect(SeatRequestState.requested.isActionable, isFalse);
      expect(SeatRequestState.confirmed.isActionable, isFalse);
      expect(SeatRequestState.full.isActionable, isFalse);
      expect(SeatRequestState.unavailable.isActionable, isFalse);
    });
  });

  group('Trip: robustez del payload', () {
    test('acepta un objeto incompleto y pone valores por defecto seguros', () {
      final trip = Trip.fromJson(<String, dynamic>{'id': 7});
      expect(trip.id, 7);
      expect(trip.origin, 'Centro');
      expect(trip.destination, 'UTB');
      expect(trip.totalSeats, 4);
      expect(trip.requests, isEmpty);
      expect(trip.driverInitials, '?');
      expect(trip.hasDriverName, isFalse);
    });

    test('el total de cupos se limita al máximo que ofrece la app', () {
      expect(Trip.fromJson(tripPayload(totalSeats: 9)).totalSeats, 4);
      expect(Trip.fromJson(tripPayload(totalSeats: 0)).totalSeats, 1);
    });

    test('el trayecto se muestra con flecha', () {
      expect(Trip.fromJson(tripPayload()).routeLabel, 'Centro → UTB');
    });

    test('reconoce las rutas que tocan la universidad', () {
      expect(Trip.fromJson(tripPayload()).touchesCampus, isTrue);
      expect(
        Trip.fromJson(tripPayload(origin: 'Centro', destination: 'Manga'))
            .touchesCampus,
        isFalse,
      );
    });
  });

  group('Trip: copias', () {
    test(
      'copyWith cambia solo lo indicado y deja el objeto original intacto',
      () {
        final original = Trip.fromJson(tripPayload(availableSeats: 3));
        final actualizado = original.copyWith(availableSeats: 1);

        expect(original.availableSeats, 3);
        expect(actualizado.availableSeats, 1);
        expect(actualizado.id, original.id);
        expect(actualizado.origin, original.origin);
      },
    );

    test('los objetos iguales se comparan por valor', () {
      expect(Trip.fromJson(tripPayload()), Trip.fromJson(tripPayload()));
      expect(
        Trip.fromJson(tripPayload()).hashCode,
        Trip.fromJson(tripPayload()).hashCode,
      );
    });
  });

  group('TripRequest', () {
    TripRequest build(int id, String status) => TripRequest(
      id: id,
      tripId: 1,
      passengerId: id + 100,
      passengerName: 'Persona $id',
      passengerPhone: '300000000$id',
      status: SeatRequestStatus.fromWire(status),
      createdAt: DateTime(2026, 10, 1),
    );

    test('agrupa por estado', () {
      final requests = <TripRequest>[
        build(1, 'pending'),
        build(2, 'accepted'),
        build(3, 'rejected'),
      ];

      expect(requests.pending.map((r) => r.id), <int>[1]);
      expect(requests.accepted.map((r) => r.id), <int>[2]);
    });

    test('usa un nombre de reserva cuando la API no manda nombre', () {
      final request = TripRequest.fromJson(<String, dynamic>{
        'id': 1,
        'trip_id': 1,
        'passenger_id': 2,
        'passenger_name': '   ',
        'status': 'pending',
        'created_at': '2026-10-01T08:00:00',
      });

      expect(request.passengerName, 'Pasajero');
      expect(request.initials, 'PA');
      expect(request.hasPhone, isFalse);
    });

    test('conserva la cantidad grupal que devuelve la API', () {
      final trip = Trip.fromJson(
        tripPayload(
          requests: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 1,
              'trip_id': 1,
              'passenger_id': 2,
              'seat_count': 4,
              'passenger_name': 'Persona titular',
              'status': 'pending',
              'created_at': '2026-10-01T08:00:00',
            },
          ],
        ),
      );

      expect(trip.requests.single.seatCount, 4);
    });

    test('un estado desconocido se trata como pendiente', () {
      expect(SeatRequestStatus.fromWire(null), SeatRequestStatus.pending);
      expect(SeatRequestStatus.fromWire('raro'), SeatRequestStatus.pending);
    });

    test('los objetos iguales se comparan por valor', () {
      expect(build(1, 'pending'), build(1, 'pending'));
      expect(build(1, 'pending'), isNot(build(1, 'accepted')));
    });
  });

  group('UserRole', () {
    test('el valor del backend decide el perfil', () {
      expect(UserRole.fromWire('driver'), UserRole.driver);
      expect(UserRole.fromWire('passenger'), UserRole.passenger);
      // Cualquier valor inesperado cae en pasajero, el valor por defecto.
      expect(UserRole.fromWire(null), UserRole.passenger);
      expect(UserRole.fromWire('otro'), UserRole.passenger);
    });

    test('el valor que viaja al backend es el del enum', () {
      expect(UserRole.driver.wire, 'driver');
      expect(UserRole.passenger.wire, 'passenger');
    });

    test('cada perfil tiene su título, su modo y su insignia', () {
      expect(UserRole.driver.modeLabel, 'Modo conductor');
      expect(UserRole.passenger.modeLabel, 'Modo pasajero');
      expect(UserRole.driver.registrationLabel, 'Registro como conductor');
      expect(UserRole.passenger.registrationLabel, 'Registro como pasajero');
      expect(UserRole.passenger.title, 'Soy pasajero');
    });
  });
}
