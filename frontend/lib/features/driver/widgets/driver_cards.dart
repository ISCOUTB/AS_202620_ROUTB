import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/map/place_locator.dart';
import '../../../core/models/trip.dart';
import '../../../core/models/trip_request.dart';
import '../../../core/models/trip_status.dart';
import '../../../core/network/google_maps_service.dart';
import '../../../core/theme/routb_motion.dart';
import '../../../core/theme/routb_palette.dart';
import '../../../core/theme/routb_text.dart';
import '../../../core/widgets/eta_label.dart';
import '../../../core/widgets/routb_card.dart';
import '../../../core/widgets/routb_dashed_border.dart';
import '../../../core/widgets/routb_field.dart';
import '../../../core/widgets/routb_journey_schedule.dart';
import '../../../core/widgets/routb_seats.dart';

/// `.rq`: fila de solicitud de cupo.
///
/// Muestra el avatar, el nombre, los cupos y el trayecto de la ruta, con los
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

    return RoutbCard(
      onTap: onTapPreview,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              InitialsAvatar(
                name: request.passengerName,
                initials: request.initials,
                size: 38,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.passengerName,
                      style: RoutbText.headline(16, color: palette.ink),
                    ),
                    Text(
                      '${request.seatCount} ${request.seatCount == 1 ? 'cupo' : 'cupos'}',
                      style: RoutbText.copy(13, color: palette.muted),
                    ),
                  ],
                ),
              ),
              if (busy)
                const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else ...[
                IconButton.filledTonal(
                  onPressed: onAccept,
                  tooltip: 'Aceptar a ${request.passengerName}',
                  style: IconButton.styleFrom(
                    backgroundColor: palette.mintSurface,
                    foregroundColor: palette.onMintSurface,
                  ),
                  icon: const Icon(Icons.check_rounded),
                ),
                IconButton(
                  onPressed: onReject,
                  tooltip: 'Rechazar a ${request.passengerName}',
                  style: IconButton.styleFrom(
                    foregroundColor: palette.onRoseSurface,
                  ),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ],
          ),
          const Divider(height: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${trip.routeLabel} · ${trip.departureDateLabel} ${trip.departureLabel}',
                style: RoutbText.copy(
                  13,
                  color: palette.ink,
                  weight: FontWeight.w700,
                ),
              ),
              for (final stop in request.stops) ...[
                const SizedBox(height: 4),
                Text(
                  '${stop.addressText} · ${stop.seats} ${stop.seats == 1 ? 'persona' : 'personas'}',
                  style: RoutbText.copy(13, color: palette.muted),
                ),
                if (stop.etaEstimated != null)
                  EtaLabel(eta: stop.etaEstimated!, compact: true),
                DetourBadge(trip: trip, stopAddress: stop.addressText),
              ],
              if (onTapPreview != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Icon(
                        Icons.map_outlined,
                        size: 18,
                        color: palette.onBrandSurface,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Previsualizar ruta',
                          style: RoutbText.copy(
                            13,
                            color: palette.onBrandSurface,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// `.ro`: tarjeta de una ruta publicada.
///
/// Tocar la tarjeta la selecciona, que es lo que actualiza el hero, el mapa y el
/// contador de cupos. La flecha abre el detalle.
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

  /// Acción de seleccionar.
  final VoidCallback onSelect;

  /// Acción de abrir el detalle.
  final VoidCallback onOpenDetail;

  /// Acción de cancelar.
  final VoidCallback onCancel;

  /// `true` la marca recién creada con un destello.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final phase = trip.phaseAt(DateTime.now());
    // Una entrada por cupo confirmado, para que una reserva grupal ocupe las
    // plazas que realmente reservó.
    final confirmedInitials = _confirmedSeatInitials(trip);

    final (Color pillBackground, Color pillForeground) = switch (phase) {
      TripPhase.onCourse => (palette.mintSurface, palette.onMintSurface),
      TripPhase.cancelled => (palette.roseSurface, palette.onRoseSurface),
      TripPhase.completed => (palette.surface, palette.muted),
      TripPhase.scheduled => (palette.amberSurface, palette.onAmberSurface),
    };

    final pending = trip.requests.pending.length;
    final radius = BorderRadius.circular(20);
    return Semantics(
      selected: selected,
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : RoutbMotion.toast,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: highlight ? palette.mintSurface : palette.card,
          borderRadius: radius,
          border: Border.all(
            color: selected ? palette.onBrandSurface : palette.line,
            width: 1.4,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onSelect,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (selected)
                              Icon(
                                Icons.check_circle_rounded,
                                color: palette.onBrandSurface,
                                size: 18,
                              ),
                            RoutbStatusPill(
                              label: phase.label,
                              background: pillBackground,
                              foreground: pillForeground,
                            ),
                            if (trip.hasAcceptedDetour)
                              RoutbBadge(
                                text: 'Desvío',
                                background: palette.amberSurface,
                                foreground: palette.onAmberSurface,
                              ),
                            if (pending > 0)
                              RoutbBadge(
                                text:
                                    '$pending ${pending == 1 ? 'solicitud' : 'solicitudes'}',
                                background: palette.amberSurface,
                                foreground: palette.onAmberSurface,
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: onOpenDetail,
                        style: IconButton.styleFrom(
                          foregroundColor: palette.onBrandSurface,
                        ),
                        tooltip: 'Ver detalle de ${trip.routeLabel}',
                        icon: const Icon(Icons.arrow_outward_rounded, size: 20),
                      ),
                    ],
                  ),
                  RoutbJourneySchedule(
                    trip: trip,
                    stops: trip.acceptedWaypoints,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Encuentro: ${trip.meetingPoint}',
                    style: RoutbText.copy(13, color: palette.muted),
                  ),
                  if (confirmedInitials.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${confirmedInitials.length} de ${trip.totalSeats} cupos confirmados',
                          style: RoutbText.copy(12, color: palette.ink),
                        ),
                        for (final initials in confirmedInitials.take(4))
                          InitialsAvatar(
                            name: initials,
                            initials: initials,
                            size: 20,
                          ),
                      ],
                    ),
                  ],
                  const Divider(height: 16),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SeatDots(
                            total: trip.totalSeats,
                            available: trip.availableSeats,
                            size: const Size(8, 12),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${trip.availableSeats}/${trip.totalSeats} cupos libres',
                            style: RoutbText.copy(12, color: palette.muted),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: onCancel,
                        style: TextButton.styleFrom(
                          foregroundColor: palette.onRoseSurface,
                        ),
                        child: const Text('Cancelar ruta'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fila del historial del conductor: una ruta cancelada o ya pasada.
///
/// Resume el trayecto, su fecha y cuántos pasajeros quedaron confirmados. Al
/// pulsarla se abre el detalle en modo de consulta.
class HistoryRouteTile extends StatelessWidget {
  const HistoryRouteTile({required this.trip, this.onTap, super.key});

  /// Ruta del historial.
  final Trip trip;

  /// Abre el detalle de la ruta. `null` deja la fila solo informativa.
  final VoidCallback? onTap;

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

    return RoutbCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  trip.routeLabel,
                  style: RoutbText.headline(18, color: palette.ink),
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.arrow_outward_rounded,
                  size: 18,
                  color: palette.onBrandSurface,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${trip.departureDateLabel} · ${trip.departureLabel}',
            style: RoutbText.copy(13, color: palette.muted),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              RoutbStatusPill(
                label: phase.label,
                background: pillBackground,
                foreground: pillForeground,
              ),
            ],
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

  /// Iniciales de quien ocupa el asiento, `–` si se ocupa sin nombre conocido, o
  /// `null` si está libre.
  final String? initials;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final label = initials;
    final takenWithoutName = label == '–';
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
          color: palette.surface,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Text('–', style: RoutbText.copy(fontSize, color: palette.muted)),
      );
    }

    // `.s`: libre, con borde discontinudo.
    return DashedBorderBox(
      color: palette.muted,
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
