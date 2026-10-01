import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/constants/zones.dart';
import 'package:frontend/core/models/trip.dart';
import 'package:frontend/core/theme/routb_palette.dart';
import 'package:frontend/core/theme/routb_theme.dart';
import 'package:frontend/core/widgets/routb_button.dart';
import 'package:frontend/core/widgets/routb_card.dart';
import 'package:frontend/core/widgets/routb_field.dart';
import 'package:frontend/core/widgets/routb_logo.dart';
import 'package:frontend/core/widgets/routb_seats.dart';
import 'package:frontend/core/widgets/routb_toast.dart';
import 'package:frontend/features/passenger/widgets/trip_card.dart';

/// Monta [child] dentro de un `MaterialApp` con el tema de ROUTB.
Widget harness(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: brightness == Brightness.light ? RoutbTheme.light() : RoutbTheme.dark(),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('Paleta', () {
    testWidgets('los dos temas instalan su propia paleta', (tester) async {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(harness(const SizedBox.shrink(), brightness: brightness));

        final context = tester.element(find.byType(Scaffold));
        final palette = RoutbPalette.of(context);

        expect(palette.brand, const Color(0xFF6C5CFF));
        expect(palette.mint, const Color(0xFF2FD3A0));
        expect(palette.amber, const Color(0xFFFF9F1C));
        expect(palette.rose, const Color(0xFFFF5C7A));
        // La tarjeta siempre contrasta con el fondo de la página.
        expect(palette.card, isNot(palette.background));
      }
    });

    testWidgets('el tema claro y el oscuro tienen fondos distintos', (tester) async {
      await tester.pumpWidget(harness(const SizedBox.shrink()));
      final light = RoutbPalette.of(tester.element(find.byType(Scaffold)));

      await tester.pumpWidget(
        harness(const SizedBox.shrink(), brightness: Brightness.dark),
      );
      // MaterialApp anima el cambio de tema, así que hay que dejar que termine.
      await tester.pumpAndSettle();
      final dark = RoutbPalette.of(tester.element(find.byType(Scaffold)));

      expect(light.background, const Color(0xFFE9E7FF));
      expect(dark.background, const Color(0xFF0A0820));
      expect(light.ink, isNot(dark.ink));
    });

    testWidgets('el acceso rápido a la paleta sigue al tema', (tester) async {
      await tester.pumpWidget(
        harness(const SizedBox.shrink(), brightness: Brightness.dark),
      );
      final context = tester.element(find.byType(Scaffold));
      expect(context.isDarkMode, isTrue);
      expect(context.palette.background, const Color(0xFF0A0820));
    });
  });

  group('RoutbButton', () {
    testWidgets('avisa al pulsar cuando está habilitado', (tester) async {
      var presses = 0;
      await tester.pumpWidget(
        harness(RoutbButton(label: 'Ingresar', onPressed: () => presses++)),
      );

      expect(find.text('Ingresar'), findsOneWidget);
      await tester.tap(find.text('Ingresar'));
      await tester.pumpAndSettle();
      expect(presses, 1);
    });

    testWidgets('no hace nada cuando no hay acción', (tester) async {
      await tester.pumpWidget(harness(const RoutbButton(label: 'Crear cuenta')));

      expect(find.text('Crear cuenta'), findsOneWidget);
      await tester.tap(find.text('Crear cuenta'));
      await tester.pumpAndSettle();
      // La etiqueta sigue en pantalla y el botón no lanzó nada.
      expect(find.text('Crear cuenta'), findsOneWidget);
    });

    testWidgets('muestra el indicador y se bloquea mientras carga', (tester) async {
      var presses = 0;
      await tester.pumpWidget(
        harness(RoutbButton(label: 'Publicar', busy: true, onPressed: () => presses++)),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Publicar'));
      // El indicador gira sin parar, así que aquí no se puede esperar a que todo
      // se detenga.
      await tester.pump(const Duration(milliseconds: 100));
      expect(presses, 0);
    });

    testWidgets('se puede activar con el teclado', (tester) async {
      var presses = 0;
      final focus = FocusNode();
      addTearDown(focus.dispose);

      await tester.pumpWidget(
        harness(
          RoutbButton(
            label: 'Aceptar',
            focusNode: focus,
            onPressed: () => presses++,
          ),
        ),
      );

      focus.requestFocus();
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(presses, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(presses, 2);
    });
  });

  group('RoutbField', () {
    testWidgets('muestra el prefijo fijo antes de escribir', (tester) async {
      await tester.pumpWidget(
        harness(const RoutbField(hint: 'Teléfono', prefixText: '+57')),
      );

      expect(find.text('+57'), findsOneWidget);
    });

    testWidgets('muestra el texto inicial y avisa de cada cambio', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      var lastValue = '';

      await tester.pumpWidget(
        harness(
          RoutbField(
            hint: 'Número de teléfono',
            controller: controller,
            onChanged: (value) => lastValue = value,
          ),
        ),
      );

      expect(find.text('Número de teléfono'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '321');
      await tester.pumpAndSettle();
      expect(controller.text, '321');
      expect(lastValue, '321');
    });

    testWidgets('alterna la visibilidad de la contraseña', (tester) async {
      await tester.pumpWidget(
        harness(RoutbField(hint: 'Contraseña', obscureToggle: true)),
      );

      TextField field() => tester.widget<TextField>(find.byType(TextField));
      expect(field().obscureText, isTrue);

      await tester.tap(find.bySemanticsLabel('Mostrar contraseña'));
      await tester.pumpAndSettle();
      expect(field().obscureText, isFalse);

      await tester.tap(find.bySemanticsLabel('Ocultar contraseña'));
      await tester.pumpAndSettle();
      expect(field().obscureText, isTrue);
    });

    testWidgets('muestra el mensaje de error debajo del campo', (tester) async {
      await tester.pumpWidget(
        harness(
          const RoutbField(hint: 'Teléfono', errorText: 'Ingresa un teléfono válido'),
        ),
      );

      expect(find.text('Ingresa un teléfono válido'), findsOneWidget);
    });
  });

  group('RoutbCheckbox', () {
    testWidgets('invierte su valor al pulsarse', (tester) async {
      var accepted = false;
      await tester.pumpWidget(
        harness(
          StatefulBuilder(
            builder: (context, setState) => RoutbCheckbox(
              value: accepted,
              onChanged: (value) => setState(() => accepted = value),
              label: 'Acepto los términos',
            ),
          ),
        ),
      );

      await tester.tap(find.text('Acepto los términos'));
      await tester.pumpAndSettle();
      expect(accepted, isTrue);
    });
  });

  group('RoutbChip', () {
    testWidgets('pinta todos los chips y avisa del que se pulsa', (tester) async {
      var tapped = '';

      await tester.pumpWidget(
        harness(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final zone in Zones.neighborhoods)
                RoutbChip(
                  label: zone.name,
                  selected: zone.name == 'Centro',
                  onTap: () => tapped = zone.name,
                ),
            ],
          ),
        ),
      );

      // Los ocho barrios del catálogo, tal como los ofrece el diseño.
      expect(find.byType(RoutbChip), findsNWidgets(8));
      expect(find.text('Getsemaní'), findsOneWidget);

      await tester.tap(find.text('Turbaco'));
      await tester.pumpAndSettle();
      expect(tapped, 'Turbaco');
    });
  });

  group('SeatDots', () {
    testWidgets('dibuja un punto por cupo y anuncia los libres', (tester) async {
      await tester.pumpWidget(harness(const SeatDots(total: 4, available: 3)));

      expect(find.bySemanticsLabel('3 de 4 cupos libres'), findsOneWidget);
      // Cuatro puntos de 10 px con 4 px de separación entre ellos.
      expect(tester.getSize(find.byType(SeatDots)).width, 4 * 10 + 3 * 4);
    });

    testWidgets('un viaje de dos cupos no dibuja cuatro', (tester) async {
      await tester.pumpWidget(harness(const SeatDots(total: 2, available: 1)));

      expect(find.bySemanticsLabel('1 de 2 cupos libres'), findsOneWidget);
      expect(tester.getSize(find.byType(SeatDots)).width, 2 * 10 + 4);
    });
  });

  group('RoutbCard', () {
    testWidgets('responde al toque cuando se le pasa una acción', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        harness(
          SizedBox(
            width: 200,
            child: RoutbCard(onTap: () => taps++, child: const Text('Tarjeta')),
          ),
        ),
      );

      await tester.tap(find.text('Tarjeta'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });
  });

  group('RoutbToast', () {
    testWidgets('aparece sobre la pantalla y se retira solo', (tester) async {
      await tester.pumpWidget(
        harness(
          Builder(
            builder: (context) => Center(
              child: RoutbButton(
                label: 'Avisar',
                onPressed: () =>
                    RoutbToast.show(context, 'Ruta publicada. Ya la ven los pasajeros'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Avisar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Ruta publicada. Ya la ven los pasajeros'), findsOneWidget);

      // Pasa la duración de visibilidad y el aviso desaparece.
      await tester.pump(const Duration(milliseconds: 2400));
      await tester.pumpAndSettle();
      expect(find.text('Ruta publicada. Ya la ven los pasajeros'), findsNothing);
    });

    testWidgets('avisa aunque el sistema pida reducir el movimiento',
        (tester) async {
      await tester.pumpWidget(
        harness(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Builder(
              builder: (context) => Center(
                child: RoutbButton(
                  label: 'Avisar',
                  onPressed: () => RoutbToast.show(context, 'Cerraste sesión'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Avisar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Cerraste sesión'), findsOneWidget);

      // Se deja pasar la duración de visibilidad para que el aviso se retire y
      // no quede ningún temporizador vivo al terminar la prueba.
      await tester.pump(const Duration(milliseconds: 2400));
      await tester.pumpAndSettle();
      expect(find.text('Cerraste sesión'), findsNothing);
    });
  });

  group('RoutbLogo', () {
    testWidgets('cada variante carga su asset', (tester) async {
      for (final variant in RoutbLogoVariant.values) {
        await tester.pumpWidget(harness(RoutbLogo(variant: variant, width: 80)));
        expect(
          find.byType(RoutbLogo),
          findsOneWidget,
          reason: variant.name,
        );
      }
    });

    testWidgets('la variante se elige según el fondo', (tester) async {
      // El resultado no depende de la variante de partida: con fondo oscuro
      // siempre va la marca blanca, y con fondo claro la de tinta.
      for (final variant in RoutbLogoVariant.values) {
        expect(variant.forBackground(true), RoutbLogoVariant.onHero);
        expect(variant.forBackground(false), RoutbLogoVariant.onSurface);
      }
    });
  });

  group('TripCard', () {
    /// Monta la tarjeta con el ancho de un móvil para que no haya desbordes.
    Widget card(Trip trip, {bool isNew = false}) => harness(
          SizedBox(
            width: 360,
            child: TripCard(trip: trip, isNew: isNew, onReserve: () {}),
          ),
        );

    testWidgets('el botón cambia de etiqueta según la solicitud', (tester) async {
      final cases = <String, ({String label, String? myStatus})>{
        'sin solicitar': (label: 'Reservar cupo', myStatus: null),
        'solicitud en espera': (label: 'Solicitud enviada', myStatus: 'pending'),
        'cupo confirmado': (label: 'Cupo confirmado', myStatus: 'accepted'),
      };

      for (final entry in cases.entries) {
        final trip = Trip.fromJson(<String, dynamic>{
          'id': 1,
          'origin': 'Centro',
          'destination': 'UTB',
          'total_seats': 4,
          'available_seats': 2,
          'departure_time': '7:00 AM',
          'driver_name': 'Enzo Fernández',
          'my_request_status': entry.value.myStatus,
        });

        await tester.pumpWidget(card(trip));
        // El punto del trayecto se mueve sin parar, así que no se espera a que
        // las animaciones terminen.
        await tester.pump();
        expect(find.text(entry.value.label), findsOneWidget, reason: entry.key);
      }
    });

    testWidgets('un viaje sin cupos no ofrece reservar', (tester) async {
      final trip = Trip.fromJson(<String, dynamic>{
        'id': 1,
        'origin': 'Centro',
        'destination': 'UTB',
        'total_seats': 4,
        'available_seats': 0,
        'departure_time': '7:00 AM',
      });

      await tester.pumpWidget(card(trip));
      await tester.pump();
      expect(find.text('Sin cupos'), findsOneWidget);
    });

    testWidgets('la insignia «Nuevo» solo se pinta cuando la marca el viaje',
        (tester) async {
      final soon = Trip.fromJson(<String, dynamic>{
        'id': 1,
        'origin': 'Centro',
        'destination': 'UTB',
        'total_seats': 4,
        'available_seats': 2,
        'departure_time': _clockPlus(const Duration(minutes: 40)),
      });

      await tester.pumpWidget(card(soon, isNew: soon.isImminent(DateTime.now())));
      await tester.pump();
      expect(find.text('Nuevo'), findsOneWidget);

      final far = Trip.fromJson(<String, dynamic>{
        'id': 2,
        'origin': 'Centro',
        'destination': 'UTB',
        'total_seats': 4,
        'available_seats': 2,
        'departure_time': _clockPlus(const Duration(hours: 5)),
      });

      await tester.pumpWidget(card(far, isNew: far.isImminent(DateTime.now())));
      await tester.pump();
      expect(find.text('Nuevo'), findsNothing);
    });
  });
}

/// Hora de salida dentro de [offset] desde ahora, en el formato de la API.
String _clockPlus(Duration offset) {
  final moment = DateTime.now().add(offset);
  final hour24 = moment.hour;
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final meridiem = hour24 < 12 ? 'AM' : 'PM';
  return '$hour12:${moment.minute.toString().padLeft(2, '0')} $meridiem';
}