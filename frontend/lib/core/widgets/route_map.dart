import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../constants/zones.dart';
import '../map/place_locator.dart';
import '../models/trip_status.dart';
import '../theme/routb_palette.dart';
import '../theme/routb_text.dart';
import '../theme/routb_theme.dart';
import 'routb_live_pill.dart';

/// Mapa de un trayecto con los mosaicos de OpenStreetMap.
///
/// Recibe el origen y el destino como texto libre. Primero pinta el catálogo
/// de barrios, si hay coincidencia, y después pide a Google Maps la coordenada
/// real del texto. Entre ambos puntos intenta la geometría de calles de Google
/// Routes; si no llega, dibuja la curva estimada de siempre.
///
/// Sobre el mapa van los nombres de los extremos y la atribución a
/// OpenStreetMap, que es obligatoria por licencia de los mosaicos.
class RouteMap extends StatefulWidget {
  const RouteMap({
    required this.origin,
    required this.destination,
    this.waypoint,
    this.waypointCoordinate,
    this.waypoints = const <String>[],
    this.waypointCoordinates = const <LatLng>[],
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

  /// Dirección o nombre del punto de parada intermedia / desvío (opcional).
  final String? waypoint;

  /// Coordenada directa de la parada intermedia (opcional).
  final LatLng? waypointCoordinate;

  /// Lista de direcciones o paradas intermedias confirmadas en la ruta.
  final List<String> waypoints;

  /// Lista directa de coordenadas de paradas intermedias.
  final List<LatLng> waypointCoordinates;

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
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap> {
  /// Espera antes de llamar a Google, para no disparar una petición por
  /// cada tecla en el buscador del pasajero.
  static const Duration _debounce = Duration(milliseconds: 450);

  final MapController _map = MapController();
  bool _mapReady = false;

  LatLng? _start;
  LatLng? _end;
  List<LatLng> _waypoints = const <LatLng>[];
  List<LatLng>? _road;
  int _epoch = 0;
  Timer? _debounceTimer;
  bool _lookupDone = false;

  List<String> get _allWaypointTexts => [
    ...widget.waypoints,
    if (widget.waypoint != null &&
        widget.waypoint!.trim().isNotEmpty &&
        !widget.waypoints.contains(widget.waypoint!.trim()))
      widget.waypoint!.trim(),
  ];

  @override
  void initState() {
    super.initState();
    _applyBestKnownPoints();
    _lookupDone = !_useRemote;
    _scheduleResolve();
  }

  @override
  void didUpdateWidget(RouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final waypointsChanged =
        !listEquals(oldWidget.waypoints, widget.waypoints) ||
        !listEquals(oldWidget.waypointCoordinates, widget.waypointCoordinates);
    if (oldWidget.origin == widget.origin &&
        oldWidget.destination == widget.destination &&
        oldWidget.waypoint == widget.waypoint &&
        oldWidget.waypointCoordinate == widget.waypointCoordinate &&
        !waypointsChanged) {
      return;
    }
    setState(() {
      _applyBestKnownPoints();
      _lookupDone = !_useRemote;
    });
    _scheduleResolve();
  }

  @override
  void dispose() {
    _epoch++;
    _debounceTimer?.cancel();
    _map.dispose();
    super.dispose();
  }

  void _applyBestKnownPoints() {
    final locator = PlaceLocator.instance;
    _start =
        locator.cachedPoint(widget.origin) ??
        PlaceLocator.catalogPoint(widget.origin);
    _end =
        locator.cachedPoint(widget.destination) ??
        PlaceLocator.catalogPoint(widget.destination);

    final points = <LatLng>[
      ...widget.waypointCoordinates,
      if (widget.waypointCoordinate != null &&
          !widget.waypointCoordinates.contains(widget.waypointCoordinate))
        widget.waypointCoordinate!,
    ];

    for (final text in _allWaypointTexts) {
      final cached =
          locator.cachedPoint(text) ?? PlaceLocator.catalogPoint(text);
      if (cached != null && !points.contains(cached)) {
        points.add(cached);
      }
    }

    _waypoints = points;
    _road = null;
  }

  void _scheduleResolve() {
    _debounceTimer?.cancel();
    if (!_useRemote) return;
    final epoch = ++_epoch;
    _debounceTimer = Timer(_debounce, () {
      unawaited(_resolve(epoch));
    });
  }

  Future<void> _resolve(int epoch) async {
    if (!_useRemote) return;

    final originText = widget.origin;
    final destinationText = widget.destination;
    final texts = _allWaypointTexts;
    final locator = PlaceLocator.instance;

    final directCoords = <LatLng>[
      ...widget.waypointCoordinates,
      if (widget.waypointCoordinate != null &&
          !widget.waypointCoordinates.contains(widget.waypointCoordinate))
        widget.waypointCoordinate!,
    ];

    final futures = <Future<LatLng?>>[
      locator.locate(originText),
      locator.locate(destinationText),
      for (final text in texts)
        text.trim().isNotEmpty ? locator.locate(text) : Future.value(null),
    ];

    final located = await Future.wait<LatLng?>(futures);
    if (!mounted || epoch != _epoch) return;

    final start = located[0];
    final end = located[1];

    final resolvedWaypoints = <LatLng>[...directCoords];
    for (var i = 2; i < located.length; i++) {
      final wp = located[i];
      if (wp != null && !resolvedWaypoints.contains(wp)) {
        resolvedWaypoints.add(wp);
      }
    }

    setState(() {
      _start = start;
      _end = end;
      _waypoints = resolvedWaypoints;
      _road = null;
      _lookupDone = true;
    });
    _fitCamera();

    if (start == null || end == null) return;

    List<LatLng>? road;
    if (resolvedWaypoints.isNotEmpty) {
      road = await locator.routeWithWaypoints(start, end, resolvedWaypoints);
    } else {
      road = await locator.route(start, end);
    }

    if (!mounted || epoch != _epoch) return;
    if (road == null || road.length < 2) return;
    setState(() => _road = road);
  }

  void _fitCamera() {
    if (!_mapReady || !mounted) return;
    final box = context.findRenderObject();
    final size = box is RenderBox && box.hasSize ? box.size : Size.zero;
    final camera = _TripCamera.forPoints(
      start: _start,
      end: _end,
      waypoints: _waypoints,
      width: size.width,
      height: size.height == 0 ? widget.height : size.height,
    );
    try {
      _map.move(camera.center, camera.zoom);
    } on Object {
      _mapReady = false;
    }
  }

  /// En las pruebas de widgets no se llama a Google: el mapa se queda con el
  /// catálogo, que es síncrono y no deja temporizadores de red.
  bool get _useRemote {
    final name = WidgetsBinding.instance.runtimeType.toString();
    return !name.contains('TestWidgetsFlutterBinding');
  }

  @override
  Widget build(BuildContext context) {
    final originText = _labelFor(widget.origin);
    final destinationText = _labelFor(widget.destination);
    final hasQuery =
        widget.origin.trim().isNotEmpty || widget.destination.trim().isNotEmpty;
    final unresolved =
        hasQuery && _lookupDone && _start == null && _end == null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(RoutbTheme.radiusTile),
      child: SizedBox(
        height: widget.height,
        child: unresolved
            ? const UnknownLocationMap()
            : _OsmMap(
                start: _start,
                end: _end,
                waypoints: _waypoints,
                road: _road,
                interactive: widget.interactive,
                animateRoute: widget.animateRoute,
                mapController: _map,
                onMapReady: () {
                  _mapReady = true;
                  _fitCamera();
                },
                overlays: _overlays(
                  originText: originText,
                  destinationText: destinationText,
                  waypointTexts: _allWaypointTexts,
                ),
              ),
      ),
    );
  }

  /// Etiqueta de un extremo: lo que escribió la persona, o la universidad si
  /// el campo está vacío, para no pintar un chip en blanco.
  static String _labelFor(String text) {
    final trimmed = text.trim();
    if (trimmed.isNotEmpty) return trimmed;
    return Zones.campus.name;
  }

  Widget _overlays({
    required String originText,
    required String destinationText,
    List<String> waypointTexts = const <String>[],
  }) {
    final stopsCount = waypointTexts.length;
    final stopLabel = stopsCount == 1
        ? 'Parada: ${waypointTexts.first}'
        : (stopsCount > 1 ? '$stopsCount paradas' : null);

    return Stack(
      children: <Widget>[
        if (widget.showPhase && widget.phase != null)
          Positioned(left: 10, top: 10, child: LivePill(phase: widget.phase!)),
        if (stopLabel != null)
          Positioned(
            left: (widget.showPhase && widget.phase != null) ? 100 : 10,
            top: 10,
            child: _MapChip(label: stopLabel, isStop: true),
          ),
        Positioned(left: 10, bottom: 10, child: _MapChip(label: originText)),
        Positioned(
          right: 10,
          bottom: widget.showAttribution ? 24 : 10,
          child: _MapChip(label: destinationText, accent: true),
        ),
        if (widget.showAttribution)
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
            'No se encontró una ubicación para este origen o destino.',
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
  const _MapChip({
    required this.label,
    this.accent = false,
    this.isStop = false,
  });

  final String label;
  final bool accent;
  final bool isStop;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    if (isStop) {
      bg = const Color(0xE6E67E22);
      fg = Colors.white;
    } else if (accent) {
      bg = const Color(0xE6E9E7FF);
      fg = const Color(0xFF17133A);
    } else {
      bg = const Color(0xD9171A3A);
      fg = Colors.white;
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: RoutbText.copy(11, color: fg, weight: FontWeight.w700),
      ),
    );
  }
}

class _OsmMap extends StatelessWidget {
  const _OsmMap({
    required this.start,
    required this.end,
    this.waypoints = const <LatLng>[],
    required this.road,
    required this.interactive,
    required this.animateRoute,
    required this.mapController,
    required this.onMapReady,
    required this.overlays,
  });

  final LatLng? start;
  final LatLng? end;
  final List<LatLng> waypoints;
  final List<LatLng>? road;
  final bool interactive;
  final bool animateRoute;
  final MapController mapController;
  final VoidCallback onMapReady;
  final Widget overlays;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final allWaypoints = waypoints;

    // El encuadre depende del tamaño real del mapa, así que se calcula dentro de
    // un `LayoutBuilder`. Ver [_TripCamera.forPoints].
    return LayoutBuilder(
      builder: (context, constraints) {
        final camera = _TripCamera.forPoints(
          start: start,
          end: end,
          waypoints: allWaypoints,
          width: constraints.maxWidth,
          height: constraints.maxHeight,
        );

        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: camera.center,
                initialZoom: camera.zoom,
                onMapReady: onMapReady,
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
                if (start != null && end != null)
                  _EstimatedRoute(
                    start: start!,
                    end: end!,
                    road: road,
                    animate: animateRoute,
                  ),
                MarkerLayer(
                  markers: <Marker>[
                    if (start != null)
                      Marker(
                        point: start!,
                        width: 22,
                        height: 22,
                        child: const _RouteDot(
                          color: Colors.white,
                          border: null,
                        ),
                      ),
                    for (var i = 0; i < allWaypoints.length; i++)
                      Marker(
                        point: allWaypoints[i],
                        width: 28,
                        height: 28,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFE67E22),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    if (end != null)
                      Marker(
                        point: end!,
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
    this.road,
  });

  final LatLng start;
  final LatLng end;
  final List<LatLng>? road;
  final bool animate;

  /// Número de tramos con los que se construye la curva.
  static const int _segments = 48;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final points = (road != null && road!.length >= 2)
        ? road!
        : _curve(start, end);
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

  factory _TripCamera.forPoints({
    required LatLng? start,
    required LatLng? end,
    LatLng? waypoint,
    List<LatLng>? waypoints,
    required double width,
    required double height,
  }) {
    final points = <LatLng>[?start, ?end, ?waypoint, ...?waypoints];
    if (points.isEmpty) {
      return _TripCamera(center: Zones.campusPoint, zoom: 13);
    }
    if (points.length == 1) {
      return _TripCamera(center: points.first, zoom: 14);
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final centerLat = (minLat + maxLat) / 2;
    final center = LatLng(centerLat, (minLng + maxLng) / 2);

    if (width <= 0 || height <= 0) {
      return _TripCamera(center: center, zoom: 13);
    }

    final cosLat = math.cos(centerLat * math.pi / 180);
    final metersPerPixel = _metersPerPixelAtZero * cosLat;

    final spanLng = (maxLng - minLng).abs() * 111320 * cosLat;
    final spanLat = (maxLat - minLat).abs() * 111320;

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
