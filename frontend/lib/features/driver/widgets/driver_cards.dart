import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/map/place_locator.dart';
import '../../../core/models/trip.dart';
import '../../../core/models/trip_request.dart';
import '../../../core/models/trip_status.dart';
import '../../../core/network/google_maps_service.dart';
import '../../../core/theme/routb_palette.dart';
import '../../../core/theme/routb_text.dart';
import '../../../core/theme/routb_theme.dart';
import '../../../core/widgets/routb_button.dart';
import '../../../core/widgets/routb_dashed_border.dart';
import '../../../core/widgets/routb_field.dart';
import '../../../core/widgets/routb_route.dart';
import '../../../core/widgets/routb_seats.dart';

/// `.rq`: fila de solicitud de cupo.
///
/// Muestra el avatar, el nombre, el teléfono y el trayecto de la ruta, con los
/// dos botones de aceptar y rechazar, y el cálculo del desvío si hay paradas.
class RequestTile extends StatelessWidget {
  const RequestTile({
    required this.request,
    required this.trip,
    required this.onAccept,
    required this.onReject,
    required this.busy,
    this.onTapPreview,
    super.key,
  });

  /// Solicitud pendiente.
  final TripRequest request;

  /// Viaje al que se refiere, para el trayecto y la hora.
  final Trip trip;

  /// Acción de aceptar.
  final VoidCallback onAccept;

  /// Acción de rechazar.
  final VoidCallback onReject;

  /// Vista previa opcional del desvío en el mapa.
  final VoidCallback? onTapPreview;

  /// `true` mientras la solicitud se está procesando.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(RoutbTheme.radiusRoute),
      ),
      child: Row(
        children: [
          InitialsAvatar(
            name: request.passengerName,
            initials: request.initials,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  request.passengerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RoutbText.headline(15, color: palette.ink),
                ),
                Text(
                  '${request.seatCount} ${request.seatCount == 1 ? 'cupo' : 'cupos'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RoutbText.copy(12, color: palette.muted),
                ),
                if (request.hasPhone) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Tel: ${request.passengerPhone}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RoutbText.copy(12, color: palette.muted),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  '${trip.routeLabel} · ${trip.departureDateLabel} ${trip.departureLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RoutbText.copy(12, color: palette.muted),
                ),
                for (final stop in request.stops) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${stop.addressText} · ${stop.seats} ${stop.seats == 1 ? 'persona' : 'personas'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: RoutbText.copy(12, color: palette.ink),
                  ),
                  DetourBadge(trip: trip, stopAddress: stop.addressText),
                ],
                if (onTapPreview != null && request.stops.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: InkWell(
                      onTap: onTapPreview,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 2,
                          horizontal: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.map_outlined,
                              size: 13,
                              color: palette.brand,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Ver ruta en el mapa',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: RoutbText.copy(
                                  11,
                                  color: palette.brand,
                                  weight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (busy)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _RoundAction(
                  icon: Icons.check_rounded,
                  color: palette.mint,
                  tooltip: 'Aceptar a ${request.passengerName}',
                  onTap: onAccept,
                ),
                const SizedBox(width: 8),
                _RoundAction(
                  icon: Icons.close_rounded,
                  color: palette.rose,
                  tooltip: 'Rechazar a ${request.passengerName}',
                  onTap: onReject,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// `.rb`: botÃ³n circular de aceptar o rechazar.
class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(icon, color: Colors.white, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.ro`: tarjeta de una ruta publicada.
///
/// Tocar la tarjeta la selecciona, que es lo que actualiza el hero, el mapa y el
/// contador de cupos. El chevron abre el detalle.
class RouteCard extends StatelessWidget {
  const RouteCard({
    required this.trip,
    required this.selected,
    required this.onSelect,
    required this.onOpenDetail,
    required this.onCancel,
    this.highlight = false,
    super.key,
  });

  /// Ruta que describe la tarjeta.
  final Trip trip;

  /// `true` si es la ruta que muestra el hero.
  final bool selected;

  /// AcciÃ³n de seleccionar.
  final VoidCallback onSelect;

  /// AcciÃ³n de abrir el detalle.
  final VoidCallback onOpenDetail;

  /// AcciÃ³n de cancelar.
  final VoidCallback onCancel;

  /// `true` la marca reciÃ©n creada con un destello.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final phase = trip.phaseAt(DateTime.now());

    final (Color pillBackground, Color pillForeground) = switch (phase) {
      TripPhase.onCourse => (palette.mintSurface, palette.onMintSurface),
      TripPhase.cancelled => (palette.roseSurface, palette.onRoseSurface),
      TripPhase.completed => (palette.surface, palette.muted),
      TripPhase.scheduled => (palette.amberSurface, palette.onAmberSurface),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: highlight ? palette.mintSurface : Colors.transparent,
        borderRadius: BorderRadius.circular(RoutbTheme.radiusRoute),
        border: Border.all(
          color: selected ? palette.brand : palette.line,
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onSelect,
          borderRadius: BorderRadius.circular(RoutbTheme.radiusRoute),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        trip.routeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RoutbText.headline(15, color: palette.ink),
                      ),
                    ),
                    RoutbStatusPill(
                      label: phase.label,
                      background: pillBackground,
                      foreground: pillForeground,
                    ),
                    if (trip.hasAcceptedDetour) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x1AE67E22),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFE67E22),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.alt_route_rounded,
                              size: 11,
                              color: Color(0xFFE67E22),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Desvío',
                              style: RoutbText.copy(
                                10,
                                color: const Color(0xFFE67E22),
                                weight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (trip.requests.pending.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: palette.amberSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: palette.amber, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.notifications_active_rounded,
                              size: 13,
                              color: palette.onAmberSurface,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${trip.requests.pending.length} ${trip.requests.pending.length == 1 ? 'solicitud' : 'solicitudes'}',
                              style: RoutbText.copy(
                                11,
                                color: palette.onAmberSurface,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    _ChevronButton(
                      onTap: onOpenDetail,
                      routeLabel: trip.routeLabel,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DashedTimeline(
                  stops: <TimelineStop>[
                    TimelineStop(
                      title: trip.origin,
                      subtitle:
                          '${trip.departureDateLabel} · salida ${trip.departureLabel}',
                      reached: phase == TripPhase.onCourse,
                    ),
                    for (final waypoint in trip.acceptedWaypoints)
                      TimelineStop(
                        title: waypoint,
                        subtitle: 'Parada confirmada de pasajero',
                        reached: false,
                      ),
                    TimelineStop(
                      title: trip.destination,
                      subtitle: 'Destino final',
                      reached: false,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Encuentro: ${trip.meetingPoint}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: RoutbText.copy(12, color: palette.muted),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${trip.availableSeats}/${trip.totalSeats} cupos libres',
                        style: RoutbText.copy(12, color: palette.muted),
                      ),
                    ),
                    RoutbTextAction(
                      label: 'Cancelar ruta',
                      color: palette.rose,
                      onPressed: onCancel,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChevronButton extends StatelessWidget {
  const _ChevronButton({required this.onTap, required this.routeLabel});

  final VoidCallback onTap;
  final String routeLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Semantics(
      button: true,
      label: 'Ver detalle de $routeLabel',
      child: Material(
        color: palette.surface,
        borderRadius: BorderRadius.circular(RoutbTheme.radiusControl),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(RoutbTheme.radiusControl),
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: palette.brand,
            ),
          ),
        ),
      ),
    );
  }
}

/// Fila del historial del conductor: una ruta cancelada o ya pasada.
///
/// Es solo informativa —no se cancela ni se selecciona— y resume el trayecto,
/// su fecha y cuántos pasajeros quedaron confirmados.
class HistoryRouteTile extends StatelessWidget {
  const HistoryRouteTile({required this.trip, super.key});

  /// Ruta del historial.
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final phase = trip.phaseAt(DateTime.now());

    final (Color pillBackground, Color pillForeground) = switch (phase) {
      TripPhase.onCourse => (palette.mintSurface, palette.onMintSurface),
      TripPhase.cancelled => (palette.roseSurface, palette.onRoseSurface),
      TripPhase.completed => (palette.surface, palette.muted),
      TripPhase.scheduled => (palette.amberSurface, palette.onAmberSurface),
    };

    final confirmed = trip.requests.accepted.fold<int>(
      0,
      (total, request) => total + request.seatCount,
    );

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(RoutbTheme.radiusRoute),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  trip.routeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RoutbText.headline(15, color: palette.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  '${trip.departureDateLabel} · ${trip.departureLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RoutbText.copy(12, color: palette.muted),
                ),
                if (confirmed > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    confirmed == 1
                        ? '1 pasajero confirmado'
                        : '$confirmed pasajeros confirmados',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RoutbText.copy(12, color: palette.muted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          RoutbStatusPill(
            label: phase.label,
            background: pillBackground,
            foreground: pillForeground,
          ),
        ],
      ),
    );
  }
}

/// `.seats`: los cuatro asientos del hero, con las iniciales de quien ya tiene
/// cupo confirmado.
class HeroSeatSlots extends StatelessWidget {
  const HeroSeatSlots({required this.trip, super.key});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final confirmed = _confirmedSeatInitials(trip);
    final occupied = trip.takenSeats;
    final slots = trip.totalSeats.clamp(1, 4);

    // El lado de cada pip sale del ancho disponible según los cupos reales del viaje.
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 6.0;
        final size = math.min(
          32.0,
          math.max(0.0, (constraints.maxWidth - gap * (slots - 1)) / slots),
        );

        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            for (var seat = 0; seat < slots; seat++)
              Padding(
                padding: EdgeInsets.only(left: seat == 0 ? 0 : gap),
                child: _SeatPip(
                  size: size,
                  initials: seat < confirmed.length
                      ? confirmed[seat]
                      : seat < occupied
                      ? '–'
                      : null,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SeatPip extends StatelessWidget {
  const _SeatPip({required this.size, required this.initials});

  /// Lado del pip, ya calculado por el llamador.
  final double size;

  /// Iniciales de quien ocupa el asiento, `â€“` si se ocupa sin nombre conocido, o
  /// `null` si estÃ¡ libre.
  final String? initials;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final label = initials;
    final takenWithoutName = label == 'â€“';
    final radius = size * 0.34;
    final fontSize = math.min(11.0, size * 0.34);

    // `.s.f`: cupo confirmado, con iniciales.
    if (label != null && !takenWithoutName) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: palette.mintGradient,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: RoutbText.copy(
              fontSize,
              color: palette.onMint,
              weight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    // `.s.x`: ocupado sin nombre a quien asignarlo.
    if (takenWithoutName) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0x4DFFFFFF),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Text(
          '–',
          style: RoutbText.copy(fontSize, color: const Color(0x99FFFFFF)),
        ),
      );
    }

    // `.s`: libre, con borde discontinudo.
    return DashedBorderBox(
      color: const Color(0x73FFFFFF),
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(width: size, height: size),
    );
  }
}

/// Cuadro de cupos del conductor, para el detalle de ruta.
class OccupiedSeatsCard extends StatelessWidget {
  const OccupiedSeatsCard({required this.trip, super.key});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final names = _confirmedSeatInitials(trip);

    return SeatSlots(
      selected: trip.totalSeats,
      maxSeats: trip.totalSeats.clamp(1, 4),
      onChanged: null,
      locked: true,
      occupiedBy: names,
    );
  }
}

/// Repite las iniciales por cada cupo de la reserva grupal para que cada
/// asiento confirmado quede identificado visualmente.
List<String> _confirmedSeatInitials(Trip trip) => [
  for (final request in trip.requests.accepted)
    for (var seat = 0; seat < request.seatCount; seat++) request.initials,
];

/// Indicador visual del tiempo y distancia extra que representa el desvío.
class DetourBadge extends StatefulWidget {
  const DetourBadge({required this.trip, required this.stopAddress, super.key});

  final Trip trip;
  final String stopAddress;

  @override
  State<DetourBadge> createState() => _DetourBadgeState();
}

class _DetourBadgeState extends State<DetourBadge> {
  RouteDetourResult? _result;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  @override
  void didUpdateWidget(DetourBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stopAddress != widget.stopAddress ||
        oldWidget.trip.origin != widget.trip.origin ||
        oldWidget.trip.destination != widget.trip.destination) {
      _calculate();
    }
  }

  Future<void> _calculate() async {
    final clean = widget.stopAddress.trim();
    if (clean.isEmpty) return;
    if (mounted) setState(() => _loading = true);

    try {
      final locator = PlaceLocator.instance;
      final points = await Future.wait([
        locator.locate(widget.trip.origin),
        locator.locate(widget.trip.destination),
        locator.locate(clean),
      ]);

      final origin = points[0];
      final destination = points[1];
      final stop = points[2];

      if (origin != null && destination != null && stop != null) {
        final detour = await GoogleMapsService.instance.computeDetour(
          origin: origin,
          destination: destination,
          waypoint: stop,
        );
        if (mounted) setState(() => _result = detour);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    if (_loading && _result == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: palette.brand,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Calculando desvío...',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: RoutbText.copy(10, color: palette.muted),
              ),
            ),
          ],
        ),
      );
    }

    if (_result == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: palette.brandSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.alt_route_rounded, size: 12, color: palette.brand),
          const SizedBox(width: 4),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'Desvío: ${_result!.summaryLabel}',
                maxLines: 1,
                style: RoutbText.copy(
                  11,
                  color: palette.brand,
                  weight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
