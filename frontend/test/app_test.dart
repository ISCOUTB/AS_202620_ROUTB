import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/app/dependencies.dart';
import 'package:frontend/app/routb_app.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/session_store.dart';
import 'package:frontend/core/theme/theme_controller.dart';
import 'package:frontend/core/widgets/routb_logo.dart';
import 'package:frontend/features/auth/data/auth_repository.dart';
import 'package:frontend/features/matching/data/matching_repository.dart';
import 'package:frontend/features/notifications/data/notifications_repository.dart';
import 'package:frontend/features/notifications/push_notification_service.dart';
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
    trips: TripRepository(api),
    matching: MatchingRepository(api),
    push: PushNotificationService(repository: NotificationsRepository(api)),
    theme: ThemeController(session),
  );
}

/// Avanza los cuadros que hacen pasar del splash al acceso.
///
/// No se usa `pumpAndSettle` porque el indicador del splash gira sin parar y
/// nunca dejaría de programar cuadros.
Future<void> _startAuthFlow(WidgetTester tester) async {
  await tester.pump(); // splash

  await tester.pump(const Duration(milliseconds: 600)); // transición de 400 ms
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('RoutbApp', () {
    testWidgets(
      'solo limita el acceso en navegadores de escritorio al redimensionar',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final dependencies = _dependencies();
        addTearDown(dependencies.dispose);
        await tester.pumpWidget(RoutbApp(dependencies: dependencies));
        await _startAuthFlow(tester);

        for (final size in const [
          Size(1920, 1080),
          Size(1280, 720),
          Size(390, 640),
        ]) {
          tester.view.physicalSize = size;
          await tester.pump();
          final width =
              kIsWeb && defaultTargetPlatform == TargetPlatform.windows
              ? size.width.clamp(0.0, 460.0)
              : size.width;
          final frame = Rect.fromLTWH(
            (size.width - width) / 2,
            0,
            width,
            size.height,
          );
          final screen = find.byType(Scaffold);
          expect(tester.getRect(screen), frame);
          expect(tester.getRect(find.byType(Overlay)), frame);
          expect(MediaQuery.sizeOf(tester.element(screen)), frame.size);
          expect(tester.takeException(), isNull);
        }
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.windows,
        TargetPlatform.android,
        TargetPlatform.iOS,
      }),
    );

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

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Iniciar sesión'), findsOneWidget);
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

    testWidgets('el acceso y el registro muestran la marca', (tester) async {
      final dependencies = _dependencies();
      addTearDown(dependencies.dispose);

      await tester.pumpWidget(RoutbApp(dependencies: dependencies));
      await _startAuthFlow(tester);

      expect(find.byType(RoutbLogo), findsOneWidget);
      expect(find.byIcon(Icons.phone_rounded), findsOneWidget);
      expect(find.text('+57'), findsNothing);

      await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(RoutbLogo), findsOneWidget);
      expect(find.byIcon(Icons.phone_rounded), findsOneWidget);
      expect(find.text('+57'), findsNothing);
      expect(
        find.text(
          'Acepto los términos y condiciones y autorizo el '
          'tratamiento de mis datos personales en ROUTB.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('el carrusel de acceso avanza entre acceso y registro', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(375, 667);
      tester.view.padding = const FakeViewPadding(top: 48);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetPadding);

      final dependencies = _dependencies();
      addTearDown(dependencies.dispose);

      await tester.pumpWidget(RoutbApp(dependencies: dependencies));
      await _startAuthFlow(tester);

      await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
      await tester.pumpAndSettle();
      expect(find.text('¿Cómo vas a viajar?'), findsNothing);
      expect(
        find.text('Únete a la comunidad universitaria de ROUTB'),
        findsOneWidget,
      );
      final backArrow = find.byIcon(Icons.arrow_back_rounded).hitTestable();
      expect(tester.getTopLeft(backArrow).dy, greaterThanOrEqualTo(48));

      await tester.tap(backArrow);
      await tester.pumpAndSettle();
      expect(find.text('Iniciar sesión'), findsOneWidget);
      await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Iniciar sesión'), findsOneWidget);
    });
  });
}
