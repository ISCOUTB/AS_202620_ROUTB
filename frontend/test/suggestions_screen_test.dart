import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/app/dependencies.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/session_store.dart';
import 'package:frontend/core/theme/routb_theme.dart';
import 'package:frontend/core/theme/theme_controller.dart';
import 'package:frontend/features/auth/data/auth_repository.dart';
import 'package:frontend/features/matching/data/matching_repository.dart';
import 'package:frontend/features/matching/presentation/suggestions_screen.dart';
import 'package:frontend/features/notifications/data/notifications_repository.dart';
import 'package:frontend/features/notifications/push_notification_service.dart';
import 'package:frontend/features/trips/data/trip_repository.dart';

const Map<String, String> _jsonHeaders = <String, String>{
  'content-type': 'application/json',
};

String _dateParameter(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

Map<String, dynamic> _tripJson({
  required int id,
  required String driver,
  required String origin,
  required String destination,
  required String direction,
  required String departure,
  required DateTime departureDate,
}) => <String, dynamic>{
  'id': id,
  'origin': origin,
  'destination': destination,
  'direction': direction,
  'total_seats': 4,
  'available_seats': 3,
  'departure_time': departure,
  'departure_date': _dateParameter(departureDate),
  'status': 'active',
  'driver_id': 20 + id,
  'driver_name': driver,
};

http.Client _client() {
  final today = DateTime.now();
  final tomorrow = today.add(const Duration(days: 1));

  final todayTrips = <Map<String, dynamic>>[
    _tripJson(
      id: 1,
      driver: 'Luis Chofer',
      origin: 'Manga',
      destination: 'UTB',
      direction: 'to_campus',
      departure: '11:59 PM',
      departureDate: today,
    ),
    _tripJson(
      id: 2,
      driver: 'Marta Chofer',
      origin: 'Centro',
      destination: 'UTB',
      direction: 'to_campus',
      departure: '11:59 PM',
      departureDate: today,
    ),
    // Ya salió: no debe aparecer.
    _tripJson(
      id: 3,
      driver: 'Viejo Chofer',
      origin: 'Manga',
      destination: 'UTB',
      direction: 'to_campus',
      departure: '12:00 AM',
      departureDate: today,
    ),
    _tripJson(
      id: 5,
      driver: 'Regreso Chofer',
      origin: 'UTB',
      destination: 'Manga',
      direction: 'from_campus',
      departure: '11:59 PM',
      departureDate: today,
    ),
  ];
  final tomorrowTrips = <Map<String, dynamic>>[
    _tripJson(
      id: 4,
      driver: 'Nuevo Chofer',
      origin: 'Manga',
      destination: 'UTB',
      direction: 'to_campus',
      departure: '8:00 AM',
      departureDate: tomorrow,
    ),
  ];

  return MockClient((request) async {
    if (request.method == 'GET' && request.url.path == '/trips/') {
      final date = request.url.queryParameters['departure_date'];
      final trips = date == _dateParameter(today) ? todayTrips : tomorrowTrips;
      return http.Response(jsonEncode(trips), 200, headers: _jsonHeaders);
    }
    return http.Response('{"detail":"Not Found"}', 404, headers: _jsonHeaders);
  });
}

Widget _app(http.Client client) {
  final session = SessionStore();
  final api = ApiClient(session, client: client);
  final dependencies = RoutbDependencies(
    session: session,
    auth: AuthRepository(api, session),
    trips: TripRepository(api),
    matching: MatchingRepository(api),
    push: PushNotificationService(repository: NotificationsRepository(api)),
    theme: ThemeController(session),
  );

  return MaterialApp(
    theme: RoutbTheme.light(),
    home: RoutbScopeDependencies(
      dependencies: dependencies,
      child: const SuggestionsScreen(),
    ),
  );
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('filtra por sentido y barrio sin fecha, hora ni grupo', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(_client()));
    await tester.pumpAndSettle();

    expect(find.text('¿Hacia dónde viajas?'), findsOneWidget);
    expect(find.text('Personas del grupo'), findsNothing);
    expect(find.text('Hoy'), findsNothing);
    expect(find.text('Mañana'), findsNothing);
    expect(find.text('Tipo de punto'), findsNothing);

    await _tapVisible(tester, find.text('Manga'));

    expect(find.text('Desde Manga'), findsOneWidget);
    expect(find.text('Luis Chofer'), findsOneWidget);
    expect(find.text('Nuevo Chofer'), findsOneWidget);
    expect(find.text('Marta Chofer'), findsNothing);
    expect(find.text('Viejo Chofer'), findsNothing);
  });

  testWidgets('el sentido cambia la lista sin pedir otra búsqueda', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(_client()));
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.text('Manga'));
    await _tapVisible(tester, find.text('Desde UTB'));

    expect(find.text('Hacia Manga'), findsOneWidget);
    expect(find.text('Regreso Chofer'), findsOneWidget);
    expect(find.text('Luis Chofer'), findsNothing);
  });

  testWidgets('la solicitud abre la hoja con dirección y sin tipo de punto', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(_client()));
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.text('Manga'));
    await _tapVisible(tester, find.text('Solicitar cupos').first);

    expect(find.text('¿Dónde te recogemos?'), findsOneWidget);
    expect(find.text('Tipo de punto'), findsNothing);
  });
}
