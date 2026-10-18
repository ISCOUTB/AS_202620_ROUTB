import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/models/trip.dart';
import '../../../core/widgets/route_map.dart';

/// Mapa de la ruta de un viaje guardado.
///
/// La lógica del mapa vive en [RouteMap], que también usa el pasajero. Aquí solo
/// se le pasa el viaje: origen y destino, que el mapa geocodifica, y la fase
/// para la píldora de estado.
class RoutbTripMap extends StatelessWidget {
  const RoutbTripMap({
    required this.trip,
    this.waypoint,
    this.waypoints,
    this.waypointCoordinate,
    this.height = 160,
    this.showPhase = true,
    this.interactive = false,
    this.showAttribution = true,
    this.animateRoute = true,
    super.key,
  });

  /// Viaje que se dibuja.
  final Trip trip;

  /// Dirección o parada de desvío intermedia a mostrar (ej. preview temporal).
  final String? waypoint;

  /// Lista opcional de paradas intermedias adicionales.
  final List<String>? waypoints;

  /// Coordenada directa de la parada intermedia.
  final LatLng? waypointCoordinate;

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
  Widget build(BuildContext context) {
    final effectiveWaypoints = <String>[
      ...trip.acceptedWaypoints,
      ...?waypoints,
      if (waypoint != null &&
          waypoint!.trim().isNotEmpty &&
          !trip.acceptedWaypoints.contains(waypoint!.trim()))
        waypoint!.trim(),
    ];

    return RouteMap(
      origin: trip.origin,
      destination: trip.destination,
      waypoints: effectiveWaypoints,
      waypointCoordinate: waypointCoordinate,
      height: height,
      phase: trip.phaseAt(DateTime.now()),
      showPhase: showPhase,
      interactive: interactive,
      showAttribution: showAttribution,
      animateRoute: animateRoute,
    );
  }
}
