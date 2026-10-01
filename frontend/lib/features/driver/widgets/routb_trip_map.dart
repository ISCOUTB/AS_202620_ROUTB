import 'package:flutter/material.dart';

import '../../../core/models/trip.dart';
import '../../../core/widgets/route_map.dart';

/// Mapa de la ruta de un viaje guardado.
///
/// La lógica del mapa vive en [RouteMap], que también usa el pasajero. Aquí solo
/// se le pasa el viaje: origen, destino y la fase para la píldora de estado.
class RoutbTripMap extends StatelessWidget {
  const RoutbTripMap({
    required this.trip,
    this.height = 160,
    this.showPhase = true,
    this.interactive = false,
    this.showAttribution = true,
    this.animateRoute = true,
    super.key,
  });

  /// Viaje que se dibuja.
  final Trip trip;

  /// Alto del contenedor.
  final double height;

  /// `false` para ocultar la píldora de estado.
  final bool showPhase;

  /// `true` permite arrastrar y acercar el mapa.
  final bool interactive;

  /// `false` para ocultar la atribución.
  final bool showAttribution;

  /// `true` dibuja la línea progresivamente al aparecer.
  final bool animateRoute;

  @override
  Widget build(BuildContext context) => RouteMap(
        origin: trip.origin,
        destination: trip.destination,
        height: height,
        phase: trip.phaseAt(DateTime.now()),
        showPhase: showPhase,
        interactive: interactive,
        showAttribution: showAttribution,
        animateRoute: animateRoute,
      );
}
