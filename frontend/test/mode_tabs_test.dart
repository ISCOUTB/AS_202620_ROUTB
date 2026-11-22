import 'dart:async';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/app/dependencies.dart';
import 'package:frontend/app/app_routes.dart';
import 'package:frontend/core/models/user_role.dart';
import 'package:frontend/core/models/trip.dart';
import 'package:frontend/core/widgets/address_search_field.dart';
import 'package:frontend/core/widgets/routb_button.dart';
import 'package:frontend/features/driver/screens/publish_route_screen.dart';
import 'package:frontend/features/passenger/screens/reserve_seats_screen.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/session_store.dart';
import 'package:frontend/core/theme/routb_theme.dart';
import 'package:frontend/core/theme/theme_controller.dart';
import 'package:frontend/core/widgets/date_quick_picker.dart';
import 'package:frontend/core/widgets/routb_hero.dart';
import 'package:frontend/core/widgets/routb_journey_board.dart';
import 'package:frontend/core/widgets/routb_nav_bar.dart';
import 'package:frontend/features/auth/data/auth_repository.dart';
import 'package:frontend/features/driver/screens/driver_screen.dart';
import 'package:frontend/features/driver/widgets/driver_cards.dart';
import 'package:frontend/features/driver/widgets/routb_trip_map.dart';
import 'package:frontend/features/matching/data/matching_repository.dart';
import 'package:frontend/features/notifications/data/notifications_repository.dart';
import 'package:frontend/features/notifications/push_notification_service.dart';
import 'package:frontend/features/passenger/screens/passenger_screen.dart';
import 'package:frontend/features/passenger/widgets/trip_card.dart';
import 'package:frontend/features/trips/data/trip_repository.dart';

const Map<String, String> _json = <String, String>{
  'content-type': 'application/json',
};

const Account _driver = Account(
  token: 't',
  name: 'Sebastián',
  role: UserRole.driver,
);
const Account _passenger = Account(
  token: 't',
  name: 'Ana',
  role: UserRole.passenger,
);

/// Un viaje en JSON, tal como lo devuelve `GET /trips/` y `my-trips`.
Map<String, dynamic> _tripJson({
  required int id,
  required String origin,
  required String destination,
  String status = 'active',
  String? date,
}) => <String, dynamic>{
  'id': id,
  'origin': origin,
  'destination': destination,
  'total_seats': 4,
  'available_seats': 2,
  'departure_time': '7:00 AM',
  'status': status,
  'departure_date': ?date,
  'driver_id': 2,
  'driver_name': 'Luis Chofer',
};

Map<String, dynamic> _profileJson({
  required String name,
  required String lastName,
  required String phone,
  required String role,
}) => <String, dynamic>{
  'id': 7,
  'name': name,
  'last_name': lastName,
  'phone': phone,
  'role': role,
};

/// Respuestas del modo conductor: una ruta vigente, otra cancelada y una
/// pasada de fecha, más el perfil.
class _DriverApi {
  late final http.Client client = MockClient((request) async {
    final path = request.url.path;
    if (request.method == 'GET' && path == '/trips/my-trips') {
      return http.Response(
        jsonEncode([
          _tripJson(id: 1, origin: 'Manga', destination: 'UTB'),
          _tripJson(
            id: 2,
            origin: 'Centro',
            destination: 'UTB',
            status: 'cancelled',
          ),
          _tripJson(
            id: 3,
            origin: 'Bocagrande',
            destination: 'UTB',
            date: '2026-01-01',
          ),
        ]),
        200,
        headers: _json,
      );
    }
    if (request.method == 'GET' && path == '/requests/trips/1') {
      return http.Response('[]', 200, headers: _json);
    }
    if (request.method == 'GET' && path == '/auth/me') {
      return http.Response(
        jsonEncode(
          _profileJson(
            name: 'Sebastián',
            lastName: 'Ríos',
            phone: '3001234567',
            role: 'driver',
          ),
        ),
        200,
        headers: _json,
      );
    }
    return http.Response('{"detail":"Not Found"}', 404, headers: _json);
  });
}

/// Respuestas del modo conductor sin rutas publicadas.
class _EmptyDriverApi {
  late final http.Client client = MockClient((request) async {
    final path = request.url.path;
    if (request.method == 'GET' && path == '/trips/my-trips') {
      return http.Response('[]', 200, headers: _json);
    }
    if (request.method == 'GET' && path == '/auth/me') {
      return http.Response(
        jsonEncode(
          _profileJson(
            name: 'Sebastián',
            lastName: 'Ríos',
            phone: '3001234567',
            role: 'driver',
          ),
        ),
        200,
        headers: _json,
      );
    }
    return http.Response('{"detail":"Not Found"}', 404, headers: _json);
  });
}

/// Respuestas del modo pasajero: sin viajes.
class _PassengerApi {
  late final http.Client client = MockClient((request) async {
    final path = request.url.path;
    if (request.method == 'GET' &&
        (path == '/trips/' || path == '/requests/me')) {
      return http.Response('[]', 200, headers: _json);
    }
    if (request.method == 'GET' && path == '/auth/me') {
      return http.Response(
        jsonEncode(
          _profileJson(
            name: 'Ana',
            lastName: 'García',
            phone: '3007654321',
            role: 'passenger',
          ),
        ),
        200,
        headers: _json,
      );
    }
    return http.Response('{"detail":"Not Found"}', 404, headers: _json);
  });
}

RoutbDependencies _dependencies(http.Client client) {
  final session = SessionStore();
  final api = ApiClient(session, client: client);
  return RoutbDependencies(
    session: session,
    auth: AuthRepository(api, session),
    trips: TripRepository(api),
    matching: MatchingRepository(api),
    push: PushNotificationService(repository: NotificationsRepository(api)),
    theme: ThemeController(session),
  );
}

/// Monta la pantalla con las dos piezas que necesita: el tema y las
/// dependencias.
Widget _app(RoutbDependencies dependencies, Widget home) => RoutbScope(
  controller: dependencies.theme,
  child: RoutbScopeDependencies(
    dependencies: dependencies,
    child: MaterialApp(theme: RoutbTheme.light(), home: home),
  ),
);

/// Pestaña de la barra inferior, para no confundirla con los títulos que
/// repiten el mismo texto dentro de cada pantalla.
Finder _tab(String label) =>
    find.descendant(of: find.byType(RoutbNavBar), matching: find.text(label));

/// Fija el tamaño de pantalla y lo restablece al terminar.
void _usePhone(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

/// Deja correr los cuadros que necesitan las peticiones y las animaciones.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

/// Abre la hoja «Editar cuenta».
Future<void> _openEditAccount(WidgetTester tester) async {
  await tester.tap(find.text('Editar cuenta'));
  await _settle(tester);
}

/// Baja hasta el final de la lista del perfil para alcanzar el botón de salir.
Future<void> _scrollToLogout(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Cerrar sesión'),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await _settle(tester);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('conserva el borrador y publica al reintentar', (tester) async {
    _usePhone(tester, const Size(390, 844));
    final submissions = <Map<String, dynamic>>[];
    final first = Completer<http.Response>();
    final dependencies = _dependencies(
      MockClient((request) async {
        submissions.add(jsonDecode(request.body) as Map<String, dynamic>);
        if (submissions.length == 1) return first.future;
        return http.Response(
          jsonEncode(_tripJson(id: 48, origin: 'Manga', destination: 'UTB')),
          201,
          headers: _json,
        );
      }),
    );
    addTearDown(dependencies.dispose);
    Trip? published;
    await tester.pumpWidget(
      _app(
        dependencies,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              child: const Text('Abrir'),
              onPressed: () async {
                published = await openPublishRouteScreen(
                  context: context,
                  driverName: 'Ana',
                  driverInitials: 'A',
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await _settle(tester);
    tester
        .widget<AddressSearchField>(find.byType(AddressSearchField))
        .onLocationSelected(
          const SelectedLocation(lat: 10.41, lng: -75.53, addressText: 'Manga'),
        );
    await tester.pump();
    await tester.tap(find.text('Publicar ruta'));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Nueva ruta'), findsOneWidget);
    first.complete(http.Response('{}', 503, headers: _json));
    await _settle(tester);
    expect(
      find.textContaining('El servidor está teniendo problemas'),
      findsOneWidget,
    );
    await tester.tap(find.text('Publicar ruta'));
    await _settle(tester);
    expect(published?.id, 48);
    expect(submissions, hasLength(2));
    expect(submissions.last, submissions.first);
  });

  testWidgets('actualiza disponibilidad si otro pasajero toma el último cupo', (
    tester,
  ) async {
    _usePhone(tester, const Size(390, 844));
    final trip = _tripJson(id: 48, origin: 'Manga', destination: 'UTB');
    final calls = <String>[];
    final dependencies = _dependencies(
      MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode({
              'detail':
                  'No hay suficientes cupos disponibles para esta solicitud',
            }),
            409,
            headers: _json,
          );
        }
        return http.Response(
          jsonEncode({...trip, 'available_seats': 0}),
          200,
          headers: _json,
        );
      }),
    );
    addTearDown(dependencies.dispose);
    await tester.pumpWidget(
      _app(
        dependencies,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              child: const Text('Abrir'),
              onPressed: () => openReserveSeatsScreen(
                context: context,
                trip: Trip.fromJson(trip),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await _settle(tester);
    tester
        .widget<AddressSearchField>(find.byType(AddressSearchField))
        .onLocationSelected(
          const SelectedLocation(lat: 10.41, lng: -75.53, addressText: 'Manga'),
        );
    await tester.pump();
    await tester.tap(find.textContaining('Enviar solicitud a'));
    await _settle(tester);
    expect(calls, ['POST /requests/trips/48', 'GET /trips/48']);
    expect(find.text('Ya no quedan cupos.'), findsOneWidget);
    expect(
      tester.widget<RoutbButton>(find.byType(RoutbButton).last).onPressed,
      isNull,
    );
  });

  testWidgets('las cuatro etiquetas caben con texto al 200 % a 320 píxeles', (
    tester,
  ) async {
    _usePhone(tester, const Size(320, 568));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        theme: RoutbTheme.dark(),
        home: Scaffold(
          bottomNavigationBar: RoutbNavBar(
            items: const [
              RoutbNavItem(label: 'Mis rutas', icon: Icons.route),
              RoutbNavItem(label: 'Historial', icon: Icons.history),
              RoutbNavItem(label: 'Seguridad', icon: Icons.shield),
              RoutbNavItem(label: 'Perfil', icon: Icons.person),
            ],
            selectedIndex: 0,
            onCenterTap: () {},
            onSelected: (_) {},
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    for (final label in ['Mis rutas', 'Historial', 'Seguridad', 'Perfil']) {
      final paragraph = tester.renderObject<RenderParagraph>(_tab(label));
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(_tab(label).hitTestable(), findsOneWidget);
    }
  });

  testWidgets('activa conductor desde Viajes y alterna sin cambiar de sesión', (
    tester,
  ) async {
    _usePhone(tester, const Size(390, 844));
    var enabled = false;
    var mode = 'passenger';
    var offline = false;
    final confirmMode = Completer<void>();
    final writes = <String>[];
    final dependencies = _dependencies(
      MockClient((request) async {
        final path = request.url.path;
        if (offline) throw http.ClientException('Sin red');
        if (request.method != 'GET') {
          expect(request.headers['Authorization'], 'Bearer t');
          writes.add(path);
        }
        if (path == '/users/me/driver') {
          expect(jsonDecode(request.body)['vehicle_plate'], 'ABC-123');
          enabled = true;
          mode = 'driver';
        }
        if (path == '/users/me/mode') {
          await confirmMode.future;
          mode = jsonDecode(request.body)['mode'];
        }
        if (path == '/auth/me' || path.startsWith('/users/me/')) {
          return http.Response(
            jsonEncode({
              ..._profileJson(
                name: 'Ana',
                lastName: 'Ruiz',
                phone: '3007654321',
                role: enabled ? 'driver' : 'passenger',
              ),
              'driver_enabled': enabled,
              'active_mode': mode,
            }),
            200,
            headers: _json,
          );
        }
        return http.Response('[]', 200, headers: _json);
      }),
    );
    addTearDown(dependencies.dispose);
    await dependencies.session.save(
      token: 't',
      name: 'Ana',
      role: UserRole.passenger,
      userId: 7,
    );
    await tester.pumpWidget(
      _app(dependencies, const ModeRoute(account: _passenger)),
    );
    await _settle(tester);
    await tester.tap(_tab('Perfil'));
    await _settle(tester);
    expect(find.byTooltip('Cambiar modo de viaje'), findsNothing);
    expect(find.text('Quiero ser conductor'), findsNothing);
    await tester.tap(_tab('Viajes'));
    await _settle(tester);
    await tester.tap(find.byTooltip('Cambiar modo de viaje'));
    await _settle(tester);
    await tester.tap(
      find.widgetWithText(
        CheckedPopupMenuItem<UserRole>,
        'Quiero ser conductor',
      ),
    );
    await _settle(tester);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Spark');
    await tester.enterText(fields.at(1), 'abc123');
    expect(fields, findsNWidgets(2));
    final gray = find.widgetWithText(ChoiceChip, 'Gris');
    await tester.ensureVisible(gray);
    await tester.tap(gray);
    await tester.tap(find.text('Habilitar modo conductor'));
    await _settle(tester);
    expect(find.byType(DriverScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Cambiar modo de viaje'));
    await _settle(tester);
    await tester.tap(
      find.widgetWithText(CheckedPopupMenuItem<UserRole>, 'Pasajero'),
    );
    await _settle(tester);
    expect(find.byType(PassengerScreen), findsOneWidget);
    confirmMode.complete();
    await _settle(tester);
    expect(writes, ['/users/me/driver', '/users/me/mode']);
    offline = true;
    final restored = await dependencies.auth.restore();
    expect(restored?.token, 't');
    expect(restored?.id, 7);
    expect(restored?.driverEnabled, true);
    expect(restored?.role, UserRole.passenger);
  });

  testWidgets(
    'el selector cabe con texto ampliado y restaura el modo si falla la confirmación',
    (tester) async {
      _usePhone(tester, const Size(320, 568));
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final switchResponse = Completer<http.Response>();
      final dependencies = _dependencies(
        MockClient((request) async {
          if (request.url.path == '/users/me/mode') {
            return switchResponse.future;
          }
          return http.Response('[]', 200, headers: _json);
        }),
      );
      addTearDown(dependencies.dispose);
      await tester.pumpWidget(
        _app(dependencies, const ModeRoute(account: _driver)),
      );
      await _settle(tester);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Cambiar modo de viaje'));
      await _settle(tester);
      await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<UserRole>, 'Pasajero'),
      );
      await _settle(tester);
      expect(find.byType(PassengerScreen), findsOneWidget);
      switchResponse.complete(http.Response('{}', 503, headers: _json));
      await _settle(tester);
      expect(find.byType(DriverScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  group('Modo conductor', () {
    testWidgets(
      'seleccionar otra ruta conserva su mapa al pasar de dos columnas a móvil',
      (tester) async {
        _usePhone(tester, const Size(1024, 768));
        final dependencies = _dependencies(
          MockClient((request) async {
            final routes =
                request.url.path == '/trips/my-trips' &&
                    request.url.queryParameters['scope'] != 'history'
                ? [
                    _tripJson(id: 1, origin: 'Manga', destination: 'UTB'),
                    _tripJson(id: 2, origin: 'Centro', destination: 'UTB'),
                  ]
                : [];
            return http.Response(jsonEncode(routes), 200, headers: _json);
          }),
        );
        addTearDown(dependencies.dispose);
        await tester.pumpWidget(
          _app(dependencies, const DriverScreen(account: _driver)),
        );
        await _settle(tester);

        final map = find.byType(RoutbTripMap);
        final cards = find.byType(RouteCard);
        expect(
          tester.getRect(map).right,
          lessThan(tester.getRect(cards.first).left),
        );
        expect(tester.widget<RoutbTripMap>(map).trip.id, 1);
        await tester.tap(
          find.descendant(of: cards.last, matching: find.text('Centro')),
        );
        await _settle(tester);

        tester.view.physicalSize = const Size(390, 844);
        await _settle(tester);
        expect(tester.widget<RoutbTripMap>(map).trip.id, 2);
        expect(
          tester.getRect(map).bottom,
          lessThan(tester.getRect(cards.first).top),
        );
      },
    );

    testWidgets('el historial vive en su propia pestaña', (tester) async {
      _usePhone(tester, const Size(390, 844));
      final dependencies = _dependencies(_DriverApi().client);
      addTearDown(dependencies.dispose);

      await tester.pumpWidget(
        _app(dependencies, DriverScreen(account: _driver)),
      );
      await _settle(tester);

      // En «Mis rutas» solo está la vigente; tampoco se asoma el historial.
      expect(find.text('Manga → UTB'), findsWidgets);
      expect(find.text('Centro → UTB'), findsNothing);
      expect(find.text('Bocagrande → UTB'), findsNothing);
      expect(find.text('Nueva ruta'), findsOneWidget);

      // La barra superior ya no trae el modo de pantalla ni la ubicación:
      // ambos viven en la pestaña de perfil.
      expect(find.byType(ThemeToggle), findsNothing);
      expect(find.byTooltip('Privacidad de ubicación'), findsNothing);

      await tester.tap(_tab('Historial'));
      await _settle(tester);

      // La cancelada y la pasada viven aquí, y la vigente ya no se ve.
      expect(find.text('Centro → UTB'), findsOneWidget);
      expect(find.text('Bocagrande → UTB'), findsOneWidget);
      expect(find.text('Manga → UTB'), findsNothing);
      expect(find.text('Nueva ruta'), findsNothing);
    });

    testWidgets('la pestaña de perfil reúne datos, modo y permisos', (
      tester,
    ) async {
      _usePhone(tester, const Size(390, 844));
      final dependencies = _dependencies(_DriverApi().client);
      addTearDown(dependencies.dispose);

      await tester.pumpWidget(
        _app(dependencies, DriverScreen(account: _driver)),
      );
      await _settle(tester);

      await tester.tap(_tab('Perfil'));
      await _settle(tester);

      expect(find.text('Sebastián Ríos'), findsOneWidget);
      expect(find.text('3001234567'), findsOneWidget);
      expect(find.text('Modo de pantalla'), findsOneWidget);
      expect(find.text('Editar cuenta'), findsOneWidget);
      expect(find.text('Editar perfil'), findsNothing);
      expect(find.text('Salir'), findsNothing);

      final openEditAccount = tester
          .widget<RoutbButton>(
            find.widgetWithText(RoutbButton, 'Editar cuenta'),
          )
          .onPressed!;
      for (var tap = 0; tap < 5; tap++) {
        openEditAccount();
      }
      await _settle(tester);
      expect(find.text('Editar datos personales'), findsOneWidget);
      expect(find.text('Cambiar contraseña'), findsOneWidget);
      expect(find.text('Eliminar mi cuenta'), findsOneWidget);
      await tester.pageBack();
      await _settle(tester);
      expect(find.text('Editar cuenta'), findsOneWidget);

      await _scrollToLogout(tester);
      expect(find.text('Permisos'), findsOneWidget);
      expect(find.text('Cerrar sesión'), findsOneWidget);
    });

    testWidgets('las tres pestañas caben en un móvil estrecho', (tester) async {
      for (final size in const <Size>[
        Size(320, 568),
        Size(360, 640),
        Size(390, 844),
      ]) {
        _usePhone(tester, size);
        final dependencies = _dependencies(_DriverApi().client);
        addTearDown(dependencies.dispose);

        await tester.pumpWidget(
          _app(dependencies, DriverScreen(account: _driver)),
        );
        await _settle(tester);

        expect(find.byType(RoutbNavBar), findsOneWidget, reason: '$size');
        await tester.tap(_tab('Historial'));
        await _settle(tester);
        await tester.tap(_tab('Perfil'));
        await _settle(tester);
        await tester.tap(_tab('Mis rutas'));
        await _settle(tester);
      }
    });

    testWidgets('carga rutas y paradas sin bucle N+1 a /requests/trips/{id}', (
      tester,
    ) async {
      final calledUrls = <String>[];
      final client = MockClient((request) async {
        calledUrls.add(
          '${request.method} ${request.url.path}${request.url.hasQuery ? '?${request.url.query}' : ''}',
        );
        if (request.method == 'GET' && request.url.path == '/trips/my-trips') {
          if (request.url.queryParameters['scope'] == 'history') {
            return http.Response('[]', 200, headers: _json);
          }
          return http.Response(
            jsonEncode(<Map<String, dynamic>>[
              <String, dynamic>{
                ..._tripJson(id: 10, origin: 'Manga', destination: 'UTB'),
                'requests': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 501,
                    'trip_id': 10,
                    'passenger_id': 88,
                    'seat_count': 2,
                    'passenger_name': 'Camila Soto',
                    'passenger_phone': '3001112233',
                    'status': 'pending',
                    'created_at': '2026-10-01T08:00:00',
                    'stops': <Map<String, dynamic>>[
                      <String, dynamic>{
                        'id': 901,
                        'seats': 2,
                        'place_type': 'door',
                        'address_text': 'Calle Real # 20-10, Manga',
                      },
                    ],
                  },
                ],
              },
              _tripJson(id: 11, origin: 'Centro', destination: 'UTB'),
            ]),
            200,
            headers: _json,
          );
        }
        return http.Response('{"detail":"Not Found"}', 404, headers: _json);
      });

      final dependencies = _dependencies(client);
      addTearDown(dependencies.dispose);

      await tester.pumpWidget(
        _app(dependencies, DriverScreen(account: _driver)),
      );
      await _settle(tester);

      expect(calledUrls, equals(<String>['GET /trips/my-trips?scope=all']));
      expect(find.text('Camila Soto'), findsOneWidget);
      expect(
        find.text('Calle Real # 20-10, Manga · 2 personas'),
        findsOneWidget,
      );
    });

    testWidgets(
      'la barra tiene Seguridad y el centro abre la ruta más próxima',
      (tester) async {
        _usePhone(tester, const Size(390, 844));
        final dependencies = _dependencies(_DriverApi().client);
        addTearDown(dependencies.dispose);

        await tester.pumpWidget(
          _app(dependencies, DriverScreen(account: _driver)),
        );
        await _settle(tester);

        expect(find.byType(RoutbNavBar), findsOneWidget);
        expect(_tab('Seguridad'), findsOneWidget);
        expect(find.byKey(const Key('routb-center-action')), findsOneWidget);

        await tester.tap(find.byKey(const Key('routb-center-action')));
        await _settle(tester);

        expect(find.text('Detalle de la ruta'), findsOneWidget);
      },
    );

    testWidgets('cinco pulsaciones de Nueva ruta consultan el perfil una vez', (
      tester,
    ) async {
      _usePhone(tester, const Size(390, 844));
      final profile = Completer<http.Response>();
      var profileCalls = 0;
      final dependencies = _dependencies(
        MockClient((request) async {
          if (request.url.path == '/auth/me') {
            profileCalls++;
            return profile.future;
          }
          return http.Response('[]', 200, headers: _json);
        }),
      );
      addTearDown(dependencies.dispose);
      await tester.pumpWidget(
        _app(dependencies, const DriverScreen(account: _driver)),
      );
      await _settle(tester);

      final publish = tester
          .widget<JourneyAction>(
            find.widgetWithText(JourneyAction, 'Nueva ruta'),
          )
          .onTap;
      for (var tap = 0; tap < 5; tap++) {
        publish();
      }
      await _settle(tester);
      expect(profileCalls, 1);
      profile.complete(http.Response('{}', 200, headers: _json));
      await _settle(tester);
      expect(find.text('Configura tu vehículo'), findsOneWidget);
      await tester.tap(find.text('Ahora no'));
      await _settle(tester);
      expect(find.text('Nueva ruta'), findsOneWidget);
    });

    testWidgets('sin rutas el centro ofrece publicar una ruta', (tester) async {
      _usePhone(tester, const Size(390, 844));
      final dependencies = _dependencies(_EmptyDriverApi().client);
      addTearDown(dependencies.dispose);

      await tester.pumpWidget(
        _app(dependencies, DriverScreen(account: _driver)),
      );
      await _settle(tester);

      await tester.tap(find.byKey(const Key('routb-center-action')));
      await _settle(tester);

      expect(find.text('No tienes una ruta activa'), findsOneWidget);
      expect(find.text('Publicar ruta'), findsOneWidget);
    });

    testWidgets('el saludo solo vive en Mis rutas', (tester) async {
      _usePhone(tester, const Size(390, 844));
      final dependencies = _dependencies(_DriverApi().client);
      addTearDown(dependencies.dispose);

      await tester.pumpWidget(
        _app(dependencies, DriverScreen(account: _driver)),
      );
      await _settle(tester);

      expect(find.textContaining('Hola, Sebastián'), findsOneWidget);
      expect(find.textContaining('Modo conductor'), findsNothing);
      expect(find.text('Salir'), findsNothing);

      for (final tab in const <String>['Historial', 'Seguridad', 'Perfil']) {
        await tester.tap(_tab(tab));
        await _settle(tester);
        expect(
          find.textContaining('Hola, Sebastián'),
          findsNothing,
          reason: 'El saludo no debe salir en $tab',
        );
      }
    });

    testWidgets('un push de solicitud nueva lleva a Mis rutas', (tester) async {
      _usePhone(tester, const Size(390, 844));
      final dependencies = _dependencies(_DriverApi().client);
      addTearDown(dependencies.dispose);

      await tester.pumpWidget(
        _app(dependencies, DriverScreen(account: _driver)),
      );
      await _settle(tester);
      await tester.tap(_tab('Historial'));
      await _settle(tester);

      dependencies.push.emitForTest(
        const RoutbPushEvent(
          title: 'Nueva solicitud',
          body: 'Un pasajero solicita cupo.',
          event: 'request_created',
          tripId: 1,
          foreground: false,
        ),
      );
      await _settle(tester);

      expect(find.text('Nueva ruta'), findsOneWidget);
    });

    testWidgets('Seguridad muestra el 123 y las tres entradas', (tester) async {
      _usePhone(tester, const Size(360, 640));
      final dependencies = _dependencies(_DriverApi().client);
      addTearDown(dependencies.dispose);

      await tester.pumpWidget(
        _app(dependencies, DriverScreen(account: _driver)),
      );
      await _settle(tester);

      await tester.tap(_tab('Seguridad'));
      await _settle(tester);

      expect(find.text('Llamar al 123'), findsOneWidget);
      expect(find.text('Contactos de emergencia'), findsOneWidget);
      expect(find.text('Consejos para conductores'), findsOneWidget);
      expect(find.text('Consejos para pasajeros'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Soporte'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Soporte'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('Perfil no recarga y conserva el contenido al volver', (
    tester,
  ) async {
    _usePhone(tester, const Size(390, 844));
    final profile = Completer<http.Response>();
    var profileCalls = 0;
    final dependencies = _dependencies(
      MockClient((request) async {
        if (request.url.path == '/auth/me') {
          profileCalls++;
          return profile.future;
        }
        return http.Response('[]', 200, headers: _json);
      }),
    );
    addTearDown(dependencies.dispose);

    await tester.pumpWidget(
      _app(dependencies, const PassengerScreen(account: _passenger)),
    );
    await _settle(tester);
    expect(profileCalls, 0);
    await tester.tap(_tab('Perfil'));
    await _settle(tester);
    expect(profileCalls, 1);
    expect(find.text('Modo de pantalla'), findsOneWidget);
    profile.complete(
      http.Response(
        jsonEncode(
          _profileJson(
            name: 'Ana',
            lastName: 'García',
            phone: '3001234567',
            role: 'passenger',
          ),
        ),
        200,
        headers: _json,
      ),
    );
    await _settle(tester);
    expect(find.text('Ana García'), findsOneWidget);
    await tester.tap(_tab('Viajes'));
    await _settle(tester);
    await tester.tap(_tab('Perfil'));
    await _settle(tester);
    expect(find.text('Ana García'), findsOneWidget);
    expect(profileCalls, 1);
  });

  group('Modo pasajero', () {
    testWidgets('el perfil también es una pestaña del pasajero', (
      tester,
    ) async {
      _usePhone(tester, const Size(390, 844));
      final dependencies = _dependencies(_PassengerApi().client);
      addTearDown(dependencies.dispose);

      await tester.pumpWidget(
        _app(dependencies, PassengerScreen(account: _passenger)),
      );
      await _settle(tester);

      await tester.tap(_tab('Perfil'));
      await _settle(tester);

      expect(find.text('Ana García'), findsOneWidget);
      expect(find.text('Pasajero'), findsOneWidget);
      expect(find.text('Modo de pantalla'), findsOneWidget);
      expect(find.text('Permisos'), findsOneWidget);
      expect(find.text('Editar cuenta'), findsOneWidget);
      expect(find.text('Editar perfil'), findsNothing);
      expect(find.text('Salir'), findsNothing);

      await _openEditAccount(tester);
      expect(find.text('Editar datos personales'), findsOneWidget);
      expect(find.text('Pasajero'), findsNothing);
      expect(find.text('Cambiar contraseña'), findsOneWidget);
      expect(find.text('Eliminar mi cuenta'), findsOneWidget);
      await tester.pageBack();
      await _settle(tester);

      await _scrollToLogout(tester);
      expect(find.text('Cerrar sesión'), findsOneWidget);
    });

    testWidgets('el saludo solo vive en Viajes', (tester) async {
      _usePhone(tester, const Size(390, 844));
      final dependencies = _dependencies(_PassengerApi().client);
      addTearDown(dependencies.dispose);

      await tester.pumpWidget(
        _app(dependencies, PassengerScreen(account: _passenger)),
      );
      await _settle(tester);

      expect(find.textContaining('Hola, Ana'), findsOneWidget);
      expect(_tab('Viajes'), findsOneWidget);
      expect(find.textContaining('Modo pasajero'), findsNothing);
      expect(find.text('Salir'), findsNothing);

      for (final tab in const <String>['Historial', 'Seguridad', 'Perfil']) {
        await tester.tap(_tab(tab));
        await _settle(tester);
        expect(
          find.textContaining('Hola, Ana'),
          findsNothing,
          reason: 'El saludo no debe salir en $tab',
        );
      }
    });

    testWidgets('la barra del pasajero tiene Seguridad y el centro', (
      tester,
    ) async {
      _usePhone(tester, const Size(320, 568));
      final dependencies = _dependencies(_PassengerApi().client);
      addTearDown(dependencies.dispose);

      await tester.pumpWidget(
        _app(dependencies, PassengerScreen(account: _passenger)),
      );
      await _settle(tester);

      expect(_tab('Seguridad'), findsOneWidget);
      expect(find.byKey(const Key('routb-center-action')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
  testWidgets(
    'una respuesta atrasada de Hoy conserva los resultados de Mañana',
    (tester) async {
      _usePhone(tester, const Size(390, 844));
      final oldResponse = Completer<http.Response>();
      var searchCalls = 0;
      String? todayParam;
      String? tomorrowParam;
      final dependencies = _dependencies(
        MockClient((request) {
          if (request.url.path != '/trips/') {
            return Future.value(http.Response('[]', 200, headers: _json));
          }
          final date = request.url.queryParameters['departure_date'];
          if (++searchCalls == 1) {
            todayParam = date;
            return oldResponse.future;
          }
          tomorrowParam = date;
          return Future.value(
            http.Response(
              jsonEncode([
                {
                  ..._tripJson(
                    id: 2,
                    origin: 'Turbaco',
                    destination: 'UTB',
                    date: date,
                  ),
                  'departure_time': '11:59 PM',
                },
              ]),
              200,
              headers: _json,
            ),
          );
        }),
      );
      addTearDown(dependencies.dispose);
      await tester.pumpWidget(
        _app(dependencies, const PassengerScreen(account: _passenger)),
      );
      await _settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(DateQuickPicker),
          matching: find.text('Mañana'),
        ),
      );
      await _settle(tester);
      expect(tomorrowParam, isNot(todayParam));
      expect(tester.widget<TripCard>(find.byType(TripCard).first).trip.id, 2);
      final lateOld = {
        ..._tripJson(
          id: 1,
          origin: 'Manga',
          destination: 'UTB',
          date: todayParam,
        ),
        'departure_time': '11:59 PM',
      };
      oldResponse.complete(
        http.Response(jsonEncode([lateOld]), 200, headers: _json),
      );
      await _settle(tester);
      expect(tester.widget<TripCard>(find.byType(TripCard).first).trip.id, 2);
    },
  );
}
