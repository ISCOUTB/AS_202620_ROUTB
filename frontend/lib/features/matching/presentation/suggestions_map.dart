import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/models/trip_suggestion.dart';
import '../../../core/theme/routb_palette.dart';

/// Mapa de las rutas sugeridas y del punto de recogida del pasajero (G14).
///
/// Cada sugerencia se dibuja con la geometría que devuelve el backend; no se
/// recalculan rutas en el cliente. Si una sugerencia llegara sin geometría, se
/// omite del mapa pero la lista de tarjetas la sigue mostrando.
class SuggestionsMap extends StatelessWidget {
  const SuggestionsMap({
    required this.suggestions,
    required this.passengerPoints,
    this.height = 210,
    super.key,
  });

  final List<TripSuggestion> suggestions;
  final List<LatLng> passengerPoints;
  final double height;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final routes = <List<LatLng>>[
      for (final suggestion in suggestions)
        if (suggestion.routePoints.length >= 2) suggestion.routePoints,
    ];
    final allPoints = <LatLng>[
      for (final route in routes) ...route,
      ...passengerPoints,
    ];
    if (allPoints.isEmpty) return const SizedBox.shrink();

    final colors = <Color>[
      palette.brand,
      palette.mint,
      palette.amber,
      palette.rose,
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: height,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: allPoints.first,
            initialZoom: 13,
            initialCameraFit: allPoints.length > 1
                ? CameraFit.coordinates(
                    coordinates: allPoints,
                    padding: const EdgeInsets.all(26),
                  )
                : null,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.none,
            ),
            backgroundColor: palette.surface,
          ),
          children: <Widget>[
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'co.iscoutb.routb',
              maxNativeZoom: 19,
            ),
            for (var index = 0; index < routes.length; index++)
              PolylineLayer(
                polylines: <Polyline>[
                  Polyline(
                    points: routes[index],
                    strokeWidth: 4,
                    color: colors[index % colors.length],
                    borderStrokeWidth: 2,
                    borderColor: Colors.white,
                  ),
                ],
              ),
            if (passengerPoints.isNotEmpty)
              MarkerLayer(
                markers: <Marker>[
                  for (final point in passengerPoints)
                    Marker(
                      point: point,
                      width: 22,
                      height: 22,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFE67E22),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.person_pin_circle_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
