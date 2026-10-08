import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/app/dependencies.dart';
import 'package:frontend/app/routb_app.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/session_store.dart';
import 'package:frontend/core/theme/theme_controller.dart';
import 'package:frontend/features/auth/data/auth_repository.dart';
import 'package:frontend/features/trips/data/geocode_repository.dart';
import 'package:frontend/features/trips/data/trip_repository.dart';

/// Dependencias reales sobre una sesión vacía.
///
/// No se hace ninguna petición: `SessionGate` solo lee el almacenamiento para
/// decidir si hay sesión, y si no la hay va al acceso.
RoutbDependencies _dependencies() {
  final session = SessionStore();
  final api = ApiClient(session);
  return RoutbDependencies(
    session: session,
    auth: AuthRepository(api, session),
    geocode: GeocodeRepository(api),
    trips: TripRepository(api),
    theme: ThemeController(session),
  );
}

/// Avanza los cuadros que hacen pasar del splash al acceso.
///
/// No se usa `pumpAndSettle` porque el indicador del splash gira sin parar y
/// nunca dejaría de programar cuadros.
Future<void> _startAuthFlow(WidgetTester tester) async {
  await tester.pump(); // splash
  await tester.pump(const Duration(milliseconds: 1000)); // resuelve la sesión
  await tester.pump(const Duration(milliseconds: 600)); // transición de 400 ms
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('RoutbApp', () {
    testWidgets('arranca en el acceso cuando no hay sesión', (tester) async {
      final dependencies = _dependencies();
      addTearDown(dependencies.dispose);

      await tester.pumpWidget(RoutbApp(dependencies: dependencies));
      await _startAuthFlow(tester);

      expect(find.text('Iniciar sesión'), findsOneWidget);
      expect(find.text('¿No tienes cuenta? Regístrate'), findsOneWidget);
    });

    testWidgets('el splash aparece mientras resuelve la sesión', (
      tester,
    ) async {
      final dependencies = _dependencies();
      addTearDown(dependencies.dispose);

      await tester.pumpWidget(RoutbApp(dependencies: dependencies));

      // El primer cuadro todavía muestra el splash, antes de resolver.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Iniciar sesión'), findsNothing);
    });

    // Regresión: el scope de dependencias estaba dentro de `home`, y
    // `SessionGate` reemplaza esa ruta con `pushReplacement`. Al desaparecer el
    // scope, la pantalla de acceso se quedaba sin dependencias y el ingreso
    // fallaba antes de tocar la red.
    testWidgets('el acceso puede leer las dependencias tras el cambio de ruta', (
      tester,
    ) async {
      final dependencies = _dependencies();
      addTearDown(dependencies.dispose);

      await tester.pumpWidget(RoutbApp(dependencies: dependencies));
      await _startAuthFlow(tester);

      // El contexto de un widget que vive en la ruta de acceso tiene que poder
      // leer las dependencias.
      final fieldContext = tester.element(find.byType(TextField).first);
      expect(() => RoutbScopeDependencies.of(fieldContext), returnsNormally);
      expect(
        RoutbScopeDependencies.of(fieldContext).trips,
        isA<TripRepository>(),
      );
      expect(
        RoutbScopeDependencies.of(fieldContext).auth,
        isA<AuthRepository>(),
      );
    });

    testWidgets('el carrusel de acceso avanza entre las tres vistas', (
      tester,
    ) async {
      final dependencies = _dependencies();
      addTearDown(dependencies.dispose);

      await tester.pumpWidget(RoutbApp(dependencies: dependencies));
      await _startAuthFlow(tester);

      // Entrar lleva a elegir perfil.
      await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('¿Cómo vas a viajar?'), findsOneWidget);

      // Elegir pasajero lleva a crear cuenta, con la insignia del perfil. Se
      // busca el subtítulo porque el título y el botón comparten texto.
      await tester.tap(find.text('Soy pasajero'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        find.text('Únete a la comunidad universitaria de ROUTB'),
        findsOneWidget,
      );
      expect(find.text('Registro como pasajero'), findsOneWidget);

      // Volver regresa a elegir perfil.
      await tester.tap(find.bySemanticsLabel('Volver'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('¿Cómo vas a viajar?'), findsOneWidget);
    });
  });
}
