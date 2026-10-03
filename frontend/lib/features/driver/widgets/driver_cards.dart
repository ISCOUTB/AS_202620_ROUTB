import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/models/trip.dart';
import '../../../core/models/trip_request.dart';
import '../../../core/models/trip_status.dart';
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
/// Muestra el avatar, el nombre, el telÃ©fono y el trayecto de la ruta, con los
/// dos botones de aceptar y rechazar.
class RequestTile extends StatelessWidget {
  const RequestTile({
    required this.request,
    required this.trip,
    required this.onAccept,
    required this.onReject,
    required this.busy,
    super.key,
  });

  /// Solicitud pendiente.
  final TripRequest request;

  /// Viaje al que se refiere, para el trayecto y la hora.
  final Trip trip;

  /// AcciÃ³n de aceptar.
  final VoidCallback onAccept;

  /// AcciÃ³n de rechazar.
  final VoidCallback onReject;

  /// `true` mientras la solicitud se estÃ¡ procesando.
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
          InitialsAvatar(name: request.passengerName, initials: request.initials),
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
                  '${request.seatCount} ${request.seatCount == 1 ? 'cupo' : 'cupos'} solicitados · incluye al pasajero',
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
                  '${trip.routeLabel} Â· ${trip.departureLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RoutbText.copy(12, color: palette.muted),
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
    final arrival = trip.estimatedArrival;

    final (Color pillBackground, Color pillForeground) = switch (phase) {
      TripPhase.onCourse => (palette.mintSurface, palette.onMintSurface),
      TripPhase.cancelled => (palette.roseSurface, palette.onRoseSurface),
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
                    const SizedBox(width: 8),
                    _ChevronButton(onTap: onOpenDetail, routeLabel: trip.routeLabel),
                  ],
                ),
                const SizedBox(height: 12),
                DashedTimeline(
                  stops: <TimelineStop>[
                    TimelineStop(
                      title: trip.origin,
                      subtitle: 'Salida ${trip.departureLabel}',
                      reached: phase == TripPhase.onCourse,
                    ),
                    TimelineStop(
                      title: trip.destination,
                      subtitle: arrival == null
                          ? 'Llegada sin estimar'
                          : 'Llegada estimada ${arrival.label}',
                      reached: false,
                    ),
                  ],
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

/// `.seats`: los cuatro asientos del hero, con las iniciales de quien ya tiene
/// cupo confirmado.
class HeroSeatSlots extends StatelessWidget {
  const HeroSeatSlots({required this.trip, super.key});

  final Trip trip;

  static const int _slots = 4;

  @override
  Widget build(BuildContext context) {
    final confirmed = trip.requests.accepted;
    final occupied = trip.takenSeats;

    // El lado de cada pip sale del ancho disponible: cuatro pips de 32 px mÃ¡s
    // sus separadores no entran en el hero de un telÃ©fono estrecho, y una fila
    // de ancho fijo desborda en lugar de encogerse.
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 6.0;
        final size = math.min(
          32.0,
          math.max(0.0, (constraints.maxWidth - gap * (_slots - 1)) / _slots),
        );

        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            for (var seat = 0; seat < _slots; seat++)
              Padding(
                padding: EdgeInsets.only(left: seat == 0 ? 0 : gap),
                child: _SeatPip(
                  size: size,
                  initials: seat < confirmed.length
                      ? confirmed[seat].initials
                      : seat < occupied
                          ? 'â€“'
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
    final names = trip.requests.accepted.map((request) => request.initials).toList();

    return SeatSlots(
      selected: trip.totalSeats,
      onChanged: null,
      locked: true,
      occupiedBy: names,
    );
  }
}
