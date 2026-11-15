import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/app/dependencies.dart';
import 'package:frontend/core/models/my_request.dart';
import 'package:frontend/core/models/trip.dart';
import 'package:frontend/core/models/trip_filters.dart';
import 'package:frontend/core/models/user_role.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/session_store.dart';
import 'package:frontend/core/theme/routb_theme.dart';
import 'package:frontend/core/theme/theme_controller.dart';
import 'package:frontend/features/auth/data/auth_repository.dart';
import 'package:frontend/features/driver/screens/driver_screen.dart';
import 'package:frontend/features/driver/widgets/driver_cards.dart';
import 'package:frontend/features/matching/data/matching_repository.dart';
import 'package:frontend/features/notifications/data/notifications_repository.dart';
import 'package:frontend/features/notifications/push_notification_service.dart';
import 'package:frontend/features/passenger/screens/passenger_screen.dart';
import 'package:frontend/features/passenger/widgets/my_trip_card.dart';
import 'package:frontend/features/passenger/widgets/trip_card.dart';
import 'package:frontend/features/trips/data/trip_repository.dart';

const Account _passenger = Account(
  token: 't',
  name: 'Ana',
  role: UserRole.passenger,
);
const Account _driver = Account(
  token: 't',
  name: 'Sebastián',
  role: UserRole.driver,
);

const Map<String, String> _jsonHeaders = <String, String>{
  'content-type': 'application/json',
};

/// Servicio de push controlable desde las pruebas, sin tocar FCM.
class _FakePushService extends PushNotificationService {
  _FakePushService(NotificationsRepository repository)
    : super(repository: repository);

  final StreamController<RoutbPushEvent> _controller =
      StreamController<RoutbPushEvent>.broadcast();

  @override
  Stream<RoutbPushEvent> get events => _controller.stream;

  void emit(RoutbPushEvent event) => _controller.add(event);

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }
}

Map<String, dynamic> _tripJson({
  required int id,
  required String driver,
  required String departure,
  required int availableSeats,
  int totalSeats = 4,
  DateTime? departureDate,
}) => <String, dynamic>{
  'id': id,
  'origin': 'Centro',
  'destination': 'UTB',
  'total_seats': totalSeats,
  'available_seats': availableSeats,
  'departure_time': departure,
  'departure_date': _dateParameter(
    departureDate ?? DateTime.now().add(const Duration(days: 1)),
  ),
  'status': 'active',
  'driver_id': 20 + id,
  'driver_name': driver,
};

Map<String, dynamic> _myRequestJson({
  String status = 'pending',
  int id = 7,
  int tripId = 1,
}) => <String, dynamic>{
  'id': id,
  'status': status,
  'created_at': '2026-09-30T14:05:00',
  'trip_id': tripId,
  'origin': 'Centro',
  'destination': 'UTB',
  'departure_time': '7:00 AM',
  'departure_date': _dateParameter(DateTime.now().add(const Duration(days: 1))),
  'total_seats': 4,
  'available_seats': 2,
  'trip_status': 'active',
  'driver_name': 'Luis Chofer',
  'driver_phone': '3015550002',
};

String _dateParameter(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

RoutbDependencies _dependencies(http.Client client, {_FakePushService? push}) {
  final session = SessionStore();
  final api = ApiClient(session, client: client);
  return RoutbDependencies(
    session: session,
    auth: AuthRepository(api, session),
    trips: TripRepository(api),
    matching: MatchingRepository(api),
    push: push ?? _FakePushService(NotificationsRepository(api)),
    theme: ThemeController(session),
  );
}

Widget _app(RoutbDependencies dependencies, Widget home) => MaterialApp(
  theme: RoutbTheme.light(),
  home: RoutbScopeDependencies(dependencies: dependencies, child: home),
);

Future<void> _usePhone(
  WidgetTester tester, [
  Size size = const Size(390, 900),
]) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

List<String> _tripDrivers(WidgetTester tester) => tester
    .widgetList<TripCard>(find.byType(TripCard))
    .map((card) => card.trip.driverName ?? '')
    .toList(growable: false);

/// Cambia la franja horaria desde el menú compacto del hero.
Future<void> _pickTimeRange(
  WidgetTester tester, {
  required String current,
  required String next,
}) async {
  await tester.tap(find.byTooltip('Filtrar por hora: $current'));
  await _settle(tester);
  await tester.tap(find.text(next).last);
  await _settle(tester);
}

/// API del pasajero con viajes y solicitudes mutables.
class _PassengerApi {
  _PassengerApi({
    List<Map<String, dynamic>>? trips,
    List<Map<String, dynamic>>? requests,
  }) : trips = trips ?? const <Map<String, dynamic>>[],
       requests = requests ?? const <Map<String, dynamic>>[];

  List<Map<String, dynamic>> trips;
  List<Map<String, dynamic>> requests;
  int deleteCalls = 0;

  late final http.Client client = MockClient((request) async {
    final path = request.url.path;
    if (request.method == 'GET' && path == '/trips/') {
      return http.Response(jsonEncode(trips), 200, headers: _jsonHeaders);
    }
    if (request.method == 'GET' && path == '/requests/me') {
      return http.Response(jsonEncode(requests), 200, headers: _jsonHeaders);
    }
    if (request.method == 'DELETE' && path == '/requests/7') {
      deleteCalls++;
      requests = const <Map<String, dynamic>>[];
      return http.Response('', 204);
    }
    return http.Response('{"detail":"Not Found"}', 404, headers: _jsonHeaders);
  });
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('Filtros y orden de resultados', () {
    Trip trip({
      required int id,
      required String driver,
      required String departure,
      required int available,
      int total = 4,
    }) => Trip.fromJson(
      _tripJson(
        id: id,
        driver: driver,
        departure: departure,
        availableSeats: available,
        totalSeats: total,
      ),
    );

    test('la franja horaria respeta mañana, mediodía y tarde', () {
      final morning = trip(
        id: 1,
        driver: 'Luis Mañana',
        departure: '7:00 AM',
        available: 1,
      );
      final midday = trip(
        id: 2,
        driver: 'Noel Mediodía',
        departure: '1:00 PM',
        available: 2,
        total: 2,
      );
      final afternoon = trip(
        id: 3,
        driver: 'Marta Tarde',
        departure: '4:00 PM',
        available: 3,
      );

      expect(
        filterAndSortTrips(<Trip>[
          morning,
          midday,
          afternoon,
        ], range: TripTimeRange.morning),
        <Trip>[morning],
      );
      expect(
        filterAndSortTrips(<Trip>[
          morning,
          midday,
          afternoon,
        ], range: TripTimeRange.midday),
        <Trip>[midday],
      );
      expect(
        filterAndSortTrips(<Trip>[
          morning,
          midday,
          afternoon,
        ], range: TripTimeRange.afternoon),
        <Trip>[afternoon],
      );
    });

    test('los tres órdenes producen secuencias distintas', () {
      final morning = trip(
        id: 1,
        driver: 'Luis Mañana',
        departure: '7:00 AM',
        available: 1,
      );
      final midday = trip(
        id: 2,
        driver: 'Noel Mediodía',
        departure: '1:00 PM',
        available: 2,
        total: 2,
      );
      final afternoon = trip(
        id: 3,
        driver: 'Marta Tarde',
        departure: '4:00 PM',
        available: 3,
      );
      final trips = <Trip>[afternoon, morning, midday];

      List<String> names(TripSortOrder order) => filterAndSortTrips(
        trips,
        order: order,
      ).map((trip) => trip.driverName!).toList();

      expect(names(TripSortOrder.earliest), <String>[
        'Luis Mañana',
        'Noel Mediodía',
        'Marta Tarde',
      ]);
      expect(names(TripSortOrder.mostSeats), <String>[
        'Marta Tarde',
        'Noel Mediodía',
        'Luis Mañana',
      ]);
      expect(names(TripSortOrder.bestMatch), <String>[
        'Noel Mediodía',
        'Marta Tarde',
        'Luis Mañana',
      ]);
    });

    testWidgets('el pasajero filtra los viajes por franja horaria', (
      tester,
    ) async {
      await _usePhone(tester, const Size(420, 1100));
      final api = _PassengerApi(
        trips: <Map<String, dynamic>>[
          _tripJson(
            id: 1,
            driver: 'Luis Mañana',
            departure: '7:00 AM',
            availableSeats: 2,
          ),
          _tripJson(
            id: 2,
            driver: 'Noel Mediodía',
            departure: '1:00 PM',
            availableSeats: 2,
          ),
          _tripJson(
            id: 3,
            driver: 'Marta Tarde',
            departure: '4:00 PM',
            availableSeats: 2,
          ),
        ],
      );
      final dependencies = _dependencies(api.client);
      addTearDown(dependencies.dispose);

      await tester.pumpWidget(
        _app(dependencies, const PassengerScreen(account: _passenger)),
      );
      await _settle(tester);

      expect(_tripDrivers(tester), hasLength(3));

      await _pickTimeRange(tester, current: 'Cualquier hora', next: 'Tarde');

      expect(_tripDrivers(tester), <String>['Marta Tarde']);
      expect(find.text('Luis Mañana'), findsNothing);

      await _pickTimeRange(tester, current: 'Tarde', next: 'Cualquier hora');
      expect(_tripDrivers(tester), hasLength(3));
    });

    testWidgets('el selector cambia el orden sin recargar la búsqueda', (
      tester,
    ) async {
      await _usePhone(tester, const Size(420, 1100));
      final api = _PassengerApi(
        trips: <Map<String, dynamic>>[
          _tripJson(
            id: 1,
            driver: 'Luis Mañana',
            departure: '7:00 AM',
            availableSeats: 1,
          ),
          _tripJson(
            id: 2,
            driver: 'Noel Mediodía',
            departure: '1:00 PM',
            availableSeats: 2,
            totalSeats: 2,
          ),
          _tripJson(
            id: 3,
            driver: 'Marta Tarde',
            departure: '4:00 PM',
            availableSeats: 3,
          ),
        ],
      );
      final dependencies = _dependencies(api.client);
      addTearDown(dependencies.dispose);

      await tester.pumpWidget(
        _app(dependencies, const PassengerScreen(account: _passenger)),
      );
      await _settle(tester);

      expect(_tripDrivers(tester), <String>[
        'Luis Mañana',
        'Noel Mediodía',
        'Marta Tarde',
      ]);

      await tester.tap(find.byTooltip('Ordenar: Más temprano'));
      await _settle(tester);
      await tester.tap(find.text('Más cupos libres').last);
      await _settle(tester);

      expect(_tripDrivers(tester), <String>[
        'Marta Tarde',
        'Noel Mediodía',
        'Luis Mañana',
      ]);

      await tester.tap(find.byTooltip('Ordenar: Más cupos libres'));
      await _settle(tester);
      await tester.tap(find.text('Mejor coincidencia').last);
      await _settle(tester);

      expect(_tripDrivers(tester), <String>[
        'Noel Mediodía',
        'Marta Tarde',
        'Luis Mañana',
      ]);
    });

    testWidgets('el estado vacío del filtro ofrece ver todas las horas', (
      tester,
    ) async {
      await _usePhone(tester, const Size(390, 900));
      final api = _PassengerApi(
        trips: <Map<String, dynamic>>[
          _tripJson(
            id: 1,
            driver: 'Luis Mañana',
            departure: '7:00 AM',
            availableSeats: 2,
          ),
        ],
      );
      final dependencies = _dependencies(api.client);
      addTearDown(dependencies.dispose);

      await tester.pumpWidget(
        _app(dependencies, const PassengerScreen(account: _passenger)),
      );
      await _settle(tester);

      await _pickTimeRange(tester, current: 'Cualquier hora', next: 'Tarde');

      expect(
        find.textContaining('No hay viajes en la franja tarde'),
        findsOneWidget,
      );
      expect(find.text('Ver todas las horas'), findsOneWidget);

      await tester.tap(find.text('Ver todas las horas'));
      await tester.pump();

      expect(find.byType(TripCard), findsOneWidget);
      expect(find.text('Luis Mañana'), findsOneWidget);
    });
  });

  group('Viajes que ya salieron', () {
    testWidgets('no se ofrecen en el listado del pasajero', (tester) async {
      await _usePhone(tester, const Size(390, 900));
      final api = _PassengerApi(
        trips: <Map<String, dynamic>>[
          _tripJson(
            id: 1,
            driver: 'Luis Pasado',
            departure: '7:00 AM',
            availableSeats: 2,
            departureDate: DateTime.now().subtract(const Duration(days: 1)),
          ),
          _tripJson(
            id: 2,
            driver: 'Marta Futuro',
            departure: '7:00 AM',
            availableSeats: 2,
            departureDate: DateTime.now().add(const Duration(days: 1)),
          ),
        ],
      );
      final dependencies = _dependencies(api.client);
      addTearDown(dependencies.dispose);

      await tester.pumpWidget(
        _app(dependencies, const PassengerScreen(account: _passenger)),
      );
      await _settle(tester);

      expect(_tripDrivers(tester), <String>['Marta Futuro']);
      expect(find.text('Luis Pasado'), findsNothing);
    });
  });

  group('Estado de la solicitud y cancelación rápida', () {
    testWidgets('la píldora explica el estado y anima el cambio', (
      tester,
    ) async {
      final pending = MyRequest.fromJson(_myRequestJson());
      final accepted = MyRequest.fromJson(_myRequestJson(status: 'accepted'));

      Widget pill(MyRequest request) => MaterialApp(
        theme: RoutbTheme.light(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: MyTripStatusPill(request: request),
            ),
          ),
        ),
      );

      await tester.pumpWidget(pill(pending));
      expect(find.text('Solicitud enviada'), findsOneWidget);

      await tester.pumpWidget(pill(accepted));
      await tester.pump();

      // Durante la transición conviven la píldora vieja y la nueva.
      expect(find.text('Solicitud enviada'), findsOneWidget);
      expect(find.text('Cupo confirmado'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Solicitud enviada'), findsNothing);
      expect(find.text('Cupo confirmado'), findsOneWidget);
    });

    testWidgets('la tarjeta muestra el mensaje y la frescura del sondeo', (
      tester,
    ) async {
      await _usePhone(tester, const Size(390, 900));
      final api = _PassengerApi(
        trips: const <Map<String, dynamic>>[],
        requests: <Map<String, dynamic>>[_myRequestJson()],
      );
      final dependencies = _dependencies(api.client);
      addTearDown(dependencies.dispose);

      await tester.pumpWidget(
        _app(dependencies, const PassengerScreen(account: _passenger)),
      );
      await _settle(tester);

      expect(find.text('Solicitud enviada'), findsOneWidget);
      expect(
        find.textContaining('El conductor recibió tu solicitud'),
        findsOneWidget,
      );
      expect(find.textContaining('Actualizado'), findsOneWidget);

      // El conductor acepta: el push refresca la tarjeta y apaga el sondeo.
      api.requests = <Map<String, dynamic>>[_myRequestJson(status: 'accepted')];
      (dependencies.push as _FakePushService).emit(
        const RoutbPushEvent(
          title: 'Solicitud aceptada',
          body: 'El conductor ha aceptado tu solicitud de cupo.',
          event: 'request_accepted',
          tripId: 1,
        ),
      );
      await _settle(tester);

      expect(find.text('Cupo confirmado'), findsOneWidget);
      expect(
        find.text('El conductor ha aceptado tu solicitud de cupo.'),
        findsOneWidget,
      );
      expect(find.textContaining('Actualizado'), findsNothing);

      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('una solicitud pendiente se cancela desde la tarjeta', (
      tester,
    ) async {
      await _usePhone(tester, const Size(390, 900));
      final api = _PassengerApi(
        trips: const <Map<String, dynamic>>[],
        requests: <Map<String, dynamic>>[_myRequestJson()],
      );
      final dependencies = _dependencies(api.client);
      addTearDown(dependencies.dispose);

      await tester.pumpWidget(
        _app(dependencies, const PassengerScreen(account: _passenger)),
      );
      await _settle(tester);

      expect(find.byType(MyTripCard), findsOneWidget);
      expect(find.text('Cancelar solicitud'), findsOneWidget);

      await tester.tap(find.text('Cancelar solicitud'));
      await tester.pump();
      expect(find.text('¿Cancelar tu solicitud?'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Cancelar solicitud'),
        ),
      );
      await _settle(tester);

      expect(api.deleteCalls, 1);
      expect(find.byType(MyTripCard), findsNothing);
      expect(find.text('Solicitud cancelada'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('una solicitud confirmada no ofrece cancelar en la tarjeta', (
      tester,
    ) async {
      await _usePhone(tester, const Size(390, 900));
      final api = _PassengerApi(
        trips: const <Map<String, dynamic>>[],
        requests: <Map<String, dynamic>>[_myRequestJson(status: 'accepted')],
      );
      final dependencies = _dependencies(api.client);
      addTearDown(dependencies.dispose);

      await tester.pumpWidget(
        _app(dependencies, const PassengerScreen(account: _passenger)),
      );
      await _settle(tester);

      expect(find.byType(MyTripCard), findsOneWidget);
      expect(find.text('Cancelar solicitud'), findsNothing);
    });
  });

  group('Push en primer plano', () {
    testWidgets('el conductor ve la nueva solicitud y recarga sus rutas', (
      tester,
    ) async {
      await _usePhone(tester, const Size(390, 900));
      var tripsCalls = 0;
      final client = MockClient((request) async {
        final path = request.url.path;
        if (request.method == 'GET' && path == '/trips/my-trips') {
          tripsCalls++;
          if (request.url.queryParameters['scope'] == 'history') {
            return http.Response('[]', 200, headers: _jsonHeaders);
          }
          return http.Response(
            jsonEncode(<Map<String, dynamic>>[
              _tripJson(
                id: 10,
                driver: 'Sebastián Ríos',
                departure: '7:00 AM',
                availableSeats: 2,
              ),
            ]),
            200,
            headers: _jsonHeaders,
          );
        }
        return http.Response(
          '{"detail":"Not Found"}',
          404,
          headers: _jsonHeaders,
        );
      });
      final dependencies = _dependencies(client);
      addTearDown(dependencies.dispose);

      await tester.pumpWidget(
        _app(dependencies, const DriverScreen(account: _driver)),
      );
      await _settle(tester);

      expect(tripsCalls, 2);
      expect(find.byType(RouteCard), findsOneWidget);
      expect(
        tester.widget<RouteCard>(find.byType(RouteCard)).highlight,
        isFalse,
      );

      (dependencies.push as _FakePushService).emit(
        const RoutbPushEvent(
          title: 'Nueva solicitud',
          body: 'Camila solicitó 2 cupos.',
          event: 'request_created',
          tripId: 10,
        ),
      );
      await _settle(tester);

      expect(tripsCalls, greaterThan(2));
      expect(find.text('Camila solicitó 2 cupos.'), findsOneWidget);
      expect(
        tester.widget<RouteCard>(find.byType(RouteCard)).highlight,
        isTrue,
      );

      await tester.pump(const Duration(seconds: 3));
    });

    test('los metadatos del mensaje se leen sin exponer datos sensibles', () {
      final event = RoutbPushEvent.fromMessage(
        const RemoteMessage(
          data: <String, dynamic>{'event': 'request_accepted', 'trip_id': '42'},
          notification: RemoteNotification(
            title: 'Solicitud aceptada',
            body: 'El conductor aceptó tu cupo.',
          ),
        ),
        foreground: true,
      );

      expect(event.event, 'request_accepted');
      expect(event.tripId, 42);
      expect(event.foreground, isTrue);
      expect(event.hasContent, isTrue);
    });
  });
}
