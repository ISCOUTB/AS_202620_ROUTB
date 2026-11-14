import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/app/dependencies.dart';
import 'package:frontend/core/models/user_role.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/session_store.dart';
import 'package:frontend/core/theme/routb_theme.dart';
import 'package:frontend/core/theme/theme_controller.dart';
import 'package:frontend/core/widgets/routb_nav_bar.dart';
import 'package:frontend/features/auth/data/auth_repository.dart';
import 'package:frontend/features/matching/data/matching_repository.dart';
import 'package:frontend/features/notifications/data/notifications_repository.dart';
import 'package:frontend/features/notifications/push_notification_service.dart';
import 'package:frontend/features/passenger/screens/passenger_screen.dart';
import 'package:frontend/features/passenger/widgets/my_trip_card.dart';
import 'package:frontend/features/trips/data/trip_repository.dart';

const Account _passenger = Account(
  token: 't',
  name: 'Ana',
  role: UserRole.passenger,
);

const Map<String, String> _json = <String, String>{
  'content-type': 'application/json',
};

String _date(int offsetDays) {
  final date = DateTime.now().add(Duration(days: offsetDays));
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

Map<String, dynamic> _requestJson({
  required int id,
  required String status,
  required int dayOffset,
  String tripStatus = 'active',
  String driver = 'Luis Chofer',
}) => <String, dynamic>{
  'id': id,
  'status': status,
  'created_at': '2026-09-30T14:05:00',
  'trip_id': 100 + id,
  'origin': 'Centro',
  'destination': 'UTB',
  'departure_time': '7:00 AM',
  'departure_date': _date(dayOffset),
  'meeting_point': 'Entrada principal',
  'total_seats': 4,
  'available_seats': 2,
  'trip_status': tripStatus,
  'driver_name': driver,
  'driver_phone': '3015550002',
};

class _PassengerApi {
  _PassengerApi(this.requests);

  final List<Map<String, dynamic>> requests;

  late final http.Client client = MockClient((request) async {
    if (request.method == 'GET' && request.url.path == '/trips/') {
      return http.Response('[]', 200, headers: _json);
    }
    if (request.method == 'GET' && request.url.path == '/requests/me') {
      return http.Response(jsonEncode(requests), 200, headers: _json);
    }
    return http.Response('{"detail":"Not Found"}', 404, headers: _json);
  });
}

RoutbDependencies _dependencies(_PassengerApi api) {
  final session = SessionStore();
  final client = ApiClient(session, client: api.client);
  return RoutbDependencies(
    session: session,
    auth: AuthRepository(client, session),
    trips: TripRepository(client),
    matching: MatchingRepository(client),
    push: PushNotificationService(repository: NotificationsRepository(client)),
    theme: ThemeController(session),
  );
}

Widget _app(RoutbDependencies dependencies) => MaterialApp(
  theme: RoutbTheme.light(),
  home: RoutbScopeDependencies(
    dependencies: dependencies,
    child: const PassengerScreen(account: _passenger),
  ),
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Finder _tab(String label) =>
    find.descendant(of: find.byType(RoutbNavBar), matching: find.text(label));

Finder get _center => find.byKey(const Key('routb-center-action'));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('el historial separa completados de cancelados', (tester) async {
    final api = _PassengerApi(<Map<String, dynamic>>[
      _requestJson(
        id: 1,
        status: 'pending',
        dayOffset: 1,
        driver: 'Luis Activo',
      ),
      _requestJson(
        id: 2,
        status: 'accepted',
        dayOffset: -1,
        driver: 'Luis Completó',
      ),
      _requestJson(
        id: 3,
        status: 'rejected',
        dayOffset: 1,
        driver: 'Luis Rechazó',
      ),
      _requestJson(
        id: 4,
        status: 'accepted',
        dayOffset: 1,
        tripStatus: 'cancelled',
        driver: 'Luis Canceló',
      ),
    ]);
    final dependencies = _dependencies(api);
    addTearDown(dependencies.dispose);

    await tester.pumpWidget(_app(dependencies));
    await _settle(tester);

    // El activo ya no vive en una pestaña: se abre desde el botón central.
    expect(find.text('Mis viajes'), findsNothing);
    expect(_center, findsOneWidget);

    await tester.tap(_tab('Historial'));
    await _settle(tester);

    expect(find.text('Completados'), findsOneWidget);
    expect(find.text('Cancelados'), findsOneWidget);
    expect(find.byType(MyTripCard), findsNWidgets(3));
    expect(find.text('Conductor: Luis Activo'), findsNothing);
    expect(find.text('Conductor: Luis Completó'), findsOneWidget);
    expect(find.text('Conductor: Luis Rechazó'), findsOneWidget);
    expect(find.text('Conductor: Luis Canceló'), findsOneWidget);
  });

  testWidgets('el historial vacío muestra un estado claro', (tester) async {
    final api = _PassengerApi(<Map<String, dynamic>>[
      _requestJson(
        id: 1,
        status: 'pending',
        dayOffset: 1,
        driver: 'Luis Activo',
      ),
    ]);
    final dependencies = _dependencies(api);
    addTearDown(dependencies.dispose);

    await tester.pumpWidget(_app(dependencies));
    await _settle(tester);

    await tester.tap(_tab('Historial'));
    await _settle(tester);

    expect(find.byType(MyTripCard), findsNothing);
    expect(
      find.textContaining('Todavía no tienes viajes completados ni cancelados'),
      findsOneWidget,
    );
  });

  testWidgets('el centro abre el detalle del único viaje activo', (
    tester,
  ) async {
    final api = _PassengerApi(<Map<String, dynamic>>[
      _requestJson(
        id: 1,
        status: 'pending',
        dayOffset: 1,
        driver: 'Luis Activo',
      ),
    ]);
    final dependencies = _dependencies(api);
    addTearDown(dependencies.dispose);

    await tester.pumpWidget(_app(dependencies));
    await _settle(tester);

    await tester.tap(_center);
    await _settle(tester);

    expect(find.text('Mi viaje'), findsOneWidget);
  });

  testWidgets('el centro con varios viajes activos abre la lista', (
    tester,
  ) async {
    final api = _PassengerApi(<Map<String, dynamic>>[
      _requestJson(id: 1, status: 'pending', dayOffset: 1, driver: 'Luis Uno'),
      _requestJson(id: 2, status: 'pending', dayOffset: 1, driver: 'Luis Dos'),
    ]);
    final dependencies = _dependencies(api);
    addTearDown(dependencies.dispose);

    await tester.pumpWidget(_app(dependencies));
    await _settle(tester);

    expect(
      tester.widget<RoutbNavBar>(find.byType(RoutbNavBar)).centerActive,
      isTrue,
    );

    await tester.tap(_center);
    await _settle(tester);

    expect(find.text('Viajes activos'), findsOneWidget);
    expect(find.byType(MyTripCard), findsNWidgets(2));
  });

  testWidgets('un push de solicitud aceptada abre el viaje activo', (
    tester,
  ) async {
    final api = _PassengerApi(<Map<String, dynamic>>[
      _requestJson(
        id: 1,
        status: 'pending',
        dayOffset: 1,
        driver: 'Luis Activo',
      ),
    ]);
    final dependencies = _dependencies(api);
    addTearDown(dependencies.dispose);

    await tester.pumpWidget(_app(dependencies));
    await _settle(tester);

    dependencies.push.emitForTest(
      const RoutbPushEvent(
        title: 'Solicitud aceptada',
        body: 'El conductor aceptó tu solicitud.',
        event: 'request_accepted',
        tripId: 101,
        foreground: false,
      ),
    );
    await _settle(tester);

    expect(find.text('Mi viaje'), findsOneWidget);
  });

  testWidgets('un push de rechazo lleva al historial', (tester) async {
    final api = _PassengerApi(<Map<String, dynamic>>[
      _requestJson(
        id: 1,
        status: 'pending',
        dayOffset: 1,
        driver: 'Luis Activo',
      ),
    ]);
    final dependencies = _dependencies(api);
    addTearDown(dependencies.dispose);

    await tester.pumpWidget(_app(dependencies));
    await _settle(tester);

    dependencies.push.emitForTest(
      const RoutbPushEvent(
        title: 'Solicitud rechazada',
        body: 'El conductor no pudo aceptar tu solicitud.',
        event: 'request_rejected',
        tripId: 101,
        foreground: false,
      ),
    );
    await _settle(tester);

    expect(find.text('Viajes completados y cancelados'), findsOneWidget);
  });

  testWidgets('el centro sin viaje activo ofrece volver a Viajes', (
    tester,
  ) async {
    final api = _PassengerApi(const <Map<String, dynamic>>[]);
    final dependencies = _dependencies(api);
    addTearDown(dependencies.dispose);

    await tester.pumpWidget(_app(dependencies));
    await _settle(tester);

    expect(
      tester.widget<RoutbNavBar>(find.byType(RoutbNavBar)).centerActive,
      isFalse,
    );

    await tester.tap(_center);
    await _settle(tester);

    expect(find.text('No tienes un viaje activo'), findsOneWidget);
    await tester.tap(find.text('Ir a Viajes'));
    await _settle(tester);

    expect(find.text('Viajes disponibles'), findsOneWidget);
  });

  testWidgets('las cuatro pestañas y el centro caben en un móvil estrecho', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.reset);

    final api = _PassengerApi(const <Map<String, dynamic>>[]);
    final dependencies = _dependencies(api);
    addTearDown(dependencies.dispose);

    await tester.pumpWidget(_app(dependencies));
    await _settle(tester);

    expect(_tab('Viajes'), findsOneWidget);
    expect(_tab('Historial'), findsOneWidget);
    expect(_tab('Seguridad'), findsOneWidget);
    expect(_tab('Perfil'), findsOneWidget);
    expect(_center, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
