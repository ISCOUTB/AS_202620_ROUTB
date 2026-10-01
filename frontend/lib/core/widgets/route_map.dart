import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../constants/zones.dart';
import '../models/trip_status.dart';
import '../theme/routb_palette.dart';
import '../theme/routb_text.dart';
import '../theme/routb_theme.dart';
import 'routb_live_pill.dart';

/// Mapa de un trayecto con los mosaicos de OpenStreetMap.
///
/// Recibe el origen y el destino como texto libre y los resuelve contra el
/// catálogo de barrios, de modo que sirve igual para un viaje guardado (el
/// conductor) que para dos campos que alguien está escribiendo (el pasajero).
///
/// El backend no guarda geometría de rutas, así que la línea que une ambos
/// extremos es una **curva estimada** entre los dos puntos del catálogo. Por
/// eso la interfaz la rotula «Trayecto estimado» en lugar de presentarla como
/// un ruteo real.
///
/// Sobre el mapa van los nombres de los extremos y la atribución a
/// OpenStreetMap, que es obligatoria por licencia de los mosaicos.
class RouteMap extends StatelessWidget {
  const RouteMap({
    required this.origin,
    required this.destination,
    this.height = 160,
    this.phase,
    this.showPhase = false,
    this.interactive = false,
    this.showAttribution = true,
    this.animateRoute = true,
    super.key,
  });

  /// Texto del origen, tal como lo escribió la persona.
  final String origin;

  /// Texto del destino.
  final String destination;

  /// Alto del contenedor.
  final double height;

  /// Fase del viaje, para la píldora. `null` la oculta, que es lo que quiere el
  /// pasajero: en su buscador todavía no hay viaje, solo una intención.
  final TripPhase? phase;

  /// Muestra la píldora de fase sobre el mapa.
  final bool showPhase;

  /// `true` permite arrastrar y acercar el mapa.
  final bool interactive;

  /// `false` para ocultar la atribución.
  final bool showAttribution;

  /// `true` dibuja la línea progresivamente al aparecer.
  final bool animateRoute;

  @override
  Widget build(BuildContext context) {
    final from = Zones.byName(origin);
    final to = Zones.byName(destination);

    return ClipRRect(
      borderRadius: BorderRadius.circular(RoutbTheme.radiusTile),
      child: SizedBox(
        height: height,
        child: _OsmMap(
          origin: from,
          destination: to,
          interactive: interactive,
          animateRoute: animateRoute,
          overlays: _overlays(
            originText: _labelFor(origin, from),
            destinationText: _labelFor(destination, to),
          ),
        ),
      ),
    );
  }

  /// Etiqueta de un extremo: lo que escribió la persona y, si vino vacío, el
  /// nombre del barrio resuelto, para no pintar un chip en blanco.
  static String _labelFor(String text, Zone? zone) {
    final trimmed = text.trim();
    if (trimmed.isNotEmpty) return trimmed;
    return zone?.name ?? Zones.campus.name;
  }

  Widget _overlays({
    required String originText,
    required String destinationText,
  }) {
    return Stack(
      children: <Widget>[
        if (showPhase && phase != null)
          Positioned(left: 10, top: 10, child: LivePill(phase: phase!)),
        Positioned(left: 10, bottom: 10, child: _MapChip(label: originText)),
        Positioned(
          right: 10,
          bottom: showAttribution ? 24 : 10,
          child: _MapChip(label: destinationText, accent: true),
        ),
        if (showAttribution)
          // La atribución a OpenStreetMap es obligatoria por licencia de los
          // mosaicos. No se usa `SimpleAttributionWidget` porque su `Row` no
          // respeta el ancho disponible y se desborda en pantallas estrechas;
          // aquí va como una etiqueta propia, alineada y recortable.
          const Positioned(right: 0, bottom: 0, child: _Attribution()),
      ],
    );
  }
}

/// Sustituto visual cuando ni el origen ni el destino están en el catálogo.
///
/// Se mantiene la estética del mapa para no dejar un hueco raro en el hero, pero
/// se dice con claridad que no hay ubicación conocida.
class UnknownLocationMap extends StatelessWidget {
  const UnknownLocationMap({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[palette.surface, palette.line],
        ),
      ),
      child: Center(
        child: Padding(
          // El texto va suelto y centrado, sin insets de 24 px: este bloque
          // llega a medir 110 px de alto en el buscador del pasajero, y con un
          // margen amplio el mensaje salía cortado.
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Elige un barrio del catálogo para ver el trayecto en el mapa.',
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: RoutbText.copy(12, color: palette.muted),
          ),
        ),
      ),
    );
  }
}

/// `.attr`: crédito de OpenStreetMap sobre el mosaico.
class _Attribution extends StatelessWidget {
  const _Attribution();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 4, bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xB3FFFFFF),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '© OpenStreetMap',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 10, color: Color(0xFF17133A)),
      ),
    );
  }
}

/// Etiqueta sobre el mapa, con fondo oscuro para leerse en cualquier mosaico.
class _MapChip extends StatelessWidget {
  const _MapChip({required this.label, this.accent = false});

  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: accent ? const Color(0xE6E9E7FF) : const Color(0xD9171A3A),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: RoutbText.copy(
          11,
          color: accent ? const Color(0xFF17133A) : Colors.white,
          weight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _OsmMap extends StatelessWidget {
  const _OsmMap({
    required this.origin,
    required this.destination,
    required this.interactive,
    required this.animateRoute,
    required this.overlays,
  });

  final Zone? origin;
  final Zone? destination;
  final bool interactive;
  final bool animateRoute;
  final Widget overlays;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    // `_pointOf` ya resuelve el nulo a la universidad, así que los dos extremos
    // siempre tienen coordenada.
    final start = _pointOf(origin);
    final end = _pointOf(destination);

    // El encuadre depende del tamaño real del mapa, así que se calcula dentro de
    // un `LayoutBuilder`. Ver [_TripCamera.forRoute].
    return LayoutBuilder(
      builder: (context, constraints) {
        final camera = _TripCamera.forRoute(
          start: start,
          end: end,
          width: constraints.maxWidth,
          height: constraints.maxHeight,
        );

        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            FlutterMap(
              options: MapOptions(
                initialCenter: camera.center,
                initialZoom: camera.zoom,
                // El hero convive con el scroll de la pantalla, así que por
                // defecto el mapa no intercepta los gestos, como avisa el diseño.
                interactionOptions: InteractionOptions(
                  flags: interactive
                      ? InteractiveFlag.all
                      : InteractiveFlag.none,
                ),
                backgroundColor: palette.surface,
              ),
              children: <Widget>[
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'co.iscoutb.routb',
                  maxNativeZoom: 19,
                ),
                _EstimatedRoute(start: start, end: end, animate: animateRoute),
                MarkerLayer(
                  markers: <Marker>[
                    Marker(
                      point: start,
                      width: 22,
                      height: 22,
                      child: const _RouteDot(color: Colors.white, border: null),
                    ),
                    if (destination != null)
                      Marker(
                        point: end,
                        width: 26,
                        height: 26,
                        child: _RouteDot(
                          color: palette.mint,
                          border: Colors.white,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            overlays,
          ],
        );
      },
    );
  }

  static LatLng _pointOf(Zone? zone) =>
      zone == null ? Zones.campusPoint : Zones.pointOf(zone);
}

/// Curva estimada entre dos puntos, con el trazo del diseño: violeta de marca
/// de 5 px con borde blanco.
///
/// Se revela progresivamente para imitar la animación de `stroke-dashoffset`
/// del prototipo.
class _EstimatedRoute extends StatelessWidget {
  const _EstimatedRoute({
    required this.start,
    required this.end,
    required this.animate,
  });

  final LatLng start;
  final LatLng end;
  final bool animate;

  /// Número de tramos con los que se construye la curva.
  static const int _segments = 48;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final points = _curve(start, end);
    if (points.length < 2) return const SizedBox.shrink();

    Widget layer(List<LatLng> visible) => PolylineLayer(
      polylines: <Polyline>[
        Polyline(
          points: visible,
          strokeWidth: 5,
          color: palette.brand,
          borderStrokeWidth: 3,
          borderColor: Colors.white,
        ),
      ],
    );

    if (!animate || MediaQuery.disableAnimationsOf(context)) {
      return layer(points);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOut,
      builder: (context, progress, _) => layer(
        points.take(_countFor(progress, points.length)).toList(growable: false),
      ),
    );
  }

  /// Curva suave entre los dos extremos, con una desviación perpendicular para
  /// que no se lea como una recta.
  static List<LatLng> _curve(LatLng start, LatLng end) {
    final dx = end.longitude - start.longitude;
    final dy = end.latitude - start.latitude;
    final length = math.sqrt(dx * dx + dy * dy);
    if (length == 0) return <LatLng>[start, end];

    // Desvío perpendicular del 12 % de la distancia.
    final bend = length * 0.12;
    final straightMidLat = (start.latitude + end.latitude) / 2;
    final straightMidLng = (start.longitude + end.longitude) / 2;
    final controlLat = straightMidLat - (dy / length) * bend;
    final controlLng = straightMidLng + (dx / length) * bend;

    return <LatLng>[
      for (var step = 0; step <= _segments; step++)
        () {
          final t = step / _segments;
          final arc = math.sin(t * math.pi);
          return LatLng(
            straightMidLat +
                (end.latitude - straightMidLat) * t +
                (controlLat - straightMidLat) * arc,
            straightMidLng +
                (end.longitude - straightMidLng) * t +
                (controlLng - straightMidLng) * arc,
          );
        }(),
    ];
  }

  static int _countFor(double progress, int total) {
    final count = (total * progress).round().clamp(2, total);
    return count;
  }
}

/// Centro y zoom que encuadran el trayecto completo.
///
/// El cálculo usa el tamaño real del mapa a propósito. La fórmula habitual
/// `156543 / km` da el zoom para una ventana de 256 px, así que en un mapa de
/// 324 px —o de 400— el trayecto se salía por los bordes y sus extremos, con los
/// marcadores, quedaban fuera de la vista sin llegar a verse ninguno.
///
/// Además el alto y el ancho se resuelven por separado y gana el más cerrado: en
/// una franja baja y ancha —el mapa compacto del buscador— manda la altura.
class _TripCamera {
  const _TripCamera({required this.center, required this.zoom});

  final LatLng center;
  final double zoom;

  /// Metros por píxel a nivel de zoom 0 en la latitud del trayecto, con mosaicos
  /// de 256 px. Es la constante de la proyección de Mercator.
  static const double _metersPerPixelAtZero = 156543.03392;

  /// Margen que se deja alrededor del trayecto.
  ///
  /// Tiene que ser holgado porque los extremos del mapa son justo donde van las
  /// etiquetas de origen y destino y la atribución de OpenStreetMap: con menos
  /// de 20 px los marcadores quedan debajo de ellas. Aun así no puede pasar de
  /// 30, porque en el mapa compacto del buscador, de 110 px de alto, 30 por lado
  /// se comían más de la mitad y el trayecto quedaba reducido a un rabito.
  static const double _padding = 26;

  factory _TripCamera.forRoute({
    required LatLng start,
    required LatLng end,
    required double width,
    required double height,
  }) {
    final centerLat = (start.latitude + end.latitude) / 2;
    final center = LatLng(centerLat, (start.longitude + end.longitude) / 2);

    if (width <= 0 || height <= 0) {
      return _TripCamera(center: center, zoom: 13);
    }

    final cosLat = math.cos(centerLat * math.pi / 180);
    final metersPerPixel = _metersPerPixelAtZero * cosLat;

    // Un grado de longitud se acorta con la latitud; uno de latitud no.
    final spanLng = (end.longitude - start.longitude).abs() * 111320 * cosLat;
    final spanLat = (end.latitude - start.latitude).abs() * 111320;

    final usableWidth = math.max(width - 2 * _padding, 1.0);
    final usableHeight = math.max(height - 2 * _padding, 1.0);

    double zoomToFit(double spanMeters, double usablePx) {
      if (spanMeters <= 0) return double.infinity;
      return math.log(metersPerPixel * usablePx / spanMeters) / math.ln2;
    }

    final zoom = math.min(
      zoomToFit(spanLng, usableWidth),
      zoomToFit(spanLat, usableHeight),
    );

    // El tope inferior solo actúa en los trayectos largos: Turbaco está a 37 km de
    // la universidad y con un suelo más alto el encuadre no llegaba a caber, así
    // que el mapa se salía por arriba y el punto de llegada quedaba medio
    // cortado.
    return _TripCamera(center: center, zoom: zoom.clamp(8.0, 16.0));
  }
}

/// Punto de un extremo del trayecto: blanco con borde de marca el de partida,
/// menta con borde blanco el de llegada.
class _RouteDot extends StatelessWidget {
  const _RouteDot({required this.color, required this.border});

  final Color color;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: border ?? palette.brand, width: 3),
      ),
    );
  }
}
