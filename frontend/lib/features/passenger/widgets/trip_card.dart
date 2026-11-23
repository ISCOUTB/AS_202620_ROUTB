import 'package:flutter/material.dart';

import '../../../core/models/trip.dart';
import '../../../core/theme/routb_palette.dart';
import '../../../core/theme/routb_text.dart';
import '../../../core/widgets/date_quick_picker.dart';
import '../../../core/widgets/routb_card.dart';
import '../../../core/widgets/routb_journey_schedule.dart';
import '../../../core/widgets/routb_seats.dart';
import '../../../core/widgets/routb_vehicle_badge.dart';
import 'vehicle_illustration.dart';

/// Salida disponible, con recorrido, conductor y estado de la reserva.
class TripCard extends StatelessWidget {
  const TripCard({
    required this.trip,
    this.onReserve,
    this.isNew = false,
    this.index = 0,
    this.now,
    super.key,
  });

  /// Viaje que describe la tarjeta.
  final Trip trip;

  /// Acción de solicitar cupo. `null` deja el botón informativo.
  final VoidCallback? onReserve;

  /// Muestra la insignia «Nuevo».
  final bool isNew;

  /// Posición en la lista, para la entrada escalonada.
  final int index;

  /// Reloj con el que se decide si el viaje ya salió.
  ///
  /// La pantalla lo comparte con la insignia «Nuevo»; en pruebas permite fijar
  /// el instante sin depender del reloj real.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final state = trip.bookingStateAt(now ?? DateTime.now());
    final lowSeats =
        trip.status.isActive &&
        (trip.availableSeats == 1 || trip.availableSeats == 2);
    final driverName = trip.hasDriverName
        ? trip.driverName!
        : 'Conductor ROUTB';

    return RoutbCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth * 0.38).clamp(72.0, 160.0);
              final illustration = Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  VehicleIllustration(width: width),
                  if (isNew) ...[
                    const SizedBox(height: 4),
                    RoutbBadge(
                      text: 'Nuevo',
                      background: palette.mintSurface,
                      foreground: palette.onMintSurface,
                    ),
                  ],
                ],
              );
              final schedule = RoutbJourneySchedule(trip: trip, compact: true);
              if (constraints.maxWidth - width - 12 <
                  MediaQuery.textScalerOf(context).scale(116)) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [illustration, const SizedBox(height: 8), schedule],
                );
              }
              return Row(
                children: [
                  illustration,
                  const SizedBox(width: 12),
                  Expanded(child: schedule),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.flag_outlined, size: 16, color: palette.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Encuentro: ${trip.meetingPoint}',
                  style: RoutbText.copy(13, color: palette.muted),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final driver = Row(
                children: [
                  InitialsAvatar(
                    name: driverName,
                    initials: trip.driverInitials,
                    size: 32,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      driverName,
                      style: RoutbText.copy(
                        14,
                        color: palette.ink,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              );
              final seats = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${trip.availableSeats}/${trip.totalSeats} cupos libres',
                    style: RoutbText.copy(13, color: palette.ink),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SeatDots(
                        total: trip.totalSeats,
                        available: trip.availableSeats,
                      ),
                      if (lowSeats)
                        RoutbBadge(
                          text: '¡Solo ${trip.availableSeats}!',
                          background: palette.amberSurface,
                          foreground: palette.onAmberSurface,
                        ),
                    ],
                  ),
                ],
              );
              final button = _ReserveButton(state: state, onPressed: onReserve);
              final scale = MediaQuery.textScalerOf(context);
              if (constraints.maxWidth >= scale.scale(320)) {
                return Row(
                  children: [
                    Expanded(flex: 3, child: driver),
                    const SizedBox(width: 10),
                    Expanded(flex: 3, child: seats),
                    const SizedBox(width: 10),
                    Flexible(flex: 4, child: button),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (constraints.maxWidth >= scale.scale(212))
                    Row(
                      children: [
                        Expanded(child: driver),
                        const SizedBox(width: 8),
                        Flexible(child: seats),
                      ],
                    )
                  else ...[
                    driver,
                    const SizedBox(height: 8),
                    seats,
                  ],
                  const SizedBox(height: 10),
                  button,
                ],
              );
            },
          ),
          if (trip.hasVehicleInfo) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: RoutbVehicleBadge(info: trip.vehicleInfo!, dense: true),
            ),
          ],
        ],
      ),
    );
  }
}

/// `.rv`: botón de reserva en sus cuatro estados.
class _ReserveButton extends StatelessWidget {
  const _ReserveButton({required this.state, required this.onPressed});

  final SeatRequestState state;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    final (String label, Color background, Color foreground) = switch (state) {
      SeatRequestState.available => (
        'Solicitar cupos',
        palette.brand,
        palette.onBrand,
      ),
      // No hay endpoint para retirar una solicitud, así que este estado es
      // informativo: se ve que la espera está en curso, pero no admite pulsación.
      SeatRequestState.requested => (
        'Solicitud enviada',
        palette.amberSurface,
        palette.onAmberSurface,
      ),
      SeatRequestState.confirmed => (
        'Cupo confirmado',
        palette.mintSurface,
        palette.onMintSurface,
      ),
      SeatRequestState.departed => (
        'Viaje finalizado',
        palette.surface,
        palette.muted,
      ),
      SeatRequestState.full => ('Sin cupos', palette.surface, palette.muted),
      SeatRequestState.unavailable => (
        'No disponible',
        palette.surface,
        palette.muted,
      ),
    };

    final description = switch (state) {
      SeatRequestState.available => 'Elige entre 1 y 4 cupos para solicitar. El conductor decide si acepta el grupo completo.',
      SeatRequestState.requested =>
        'La solicitud está en espera. No se puede retirar desde la app.',
      SeatRequestState.confirmed =>
        'El conductor confirmó tu cupo en este viaje.',
      SeatRequestState.departed => 'Este viaje ya salió. Busca otro horario.',
      SeatRequestState.full => 'Este viaje ya no tiene cupos disponibles.',
      SeatRequestState.unavailable => 'Este viaje ya no está activo.',
    };

    return Semantics(
      button: state.isActionable,
      enabled: state.isActionable && onPressed != null,
      label: description,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: state.isActionable ? onPressed : null,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (state == SeatRequestState.confirmed) ...[
                  Icon(Icons.check_rounded, size: 15, color: foreground),
                  const SizedBox(width: 6),
                ] else if (state == SeatRequestState.requested) ...[
                  Icon(Icons.schedule_rounded, size: 15, color: foreground),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RoutbText.copy(
                      13,
                      color: foreground,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `.srch`: buscador de origen y destino del pasajero.
class SearchCard extends StatelessWidget {
  const SearchCard({
    required this.origin,
    required this.destination,
    required this.onOriginChanged,
    required this.onDestinationChanged,
    required this.selectedDate,
    required this.onDateChanged,
    super.key,
  });

  final TextEditingController origin;
  final TextEditingController destination;
  final ValueChanged<String> onOriginChanged;
  final ValueChanged<String> onDestinationChanged;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(22),
        boxShadow: palette.searchShadow,
      ),
      padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                _SearchRow(
                  marker: _DotMarker(
                    color: Colors.transparent,
                    ring: palette.brand,
                  ),
                  controller: origin,
                  hint: 'Origen (ej. Centro)',
                  semanticLabel: 'Origen',
                  onChanged: onOriginChanged,
                ),
                const Divider(height: 1),
                _SearchRow(
                  marker: _DotMarker(color: palette.mint),
                  controller: destination,
                  hint: 'Destino (ej. UTB)',
                  semanticLabel: 'Destino',
                  onChanged: onDestinationChanged,
                ),
                const Divider(height: 1),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: DateQuickPicker(
                      value: selectedDate,
                      onChanged: onDateChanged,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Marcador del buscador: círculo hueco para el origen, cuadrado para el
/// destino, como en el diseño.
class _DotMarker extends StatelessWidget {
  const _DotMarker({required this.color, this.ring});

  final Color color;
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: ring == null ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: ring == null ? null : BorderRadius.circular(3),
        border: ring == null ? null : Border.all(color: ring!, width: 3),
      ),
    );
  }
}

class _SearchRow extends StatelessWidget {
  const _SearchRow({
    required this.marker,
    required this.controller,
    required this.hint,
    required this.semanticLabel,
    required this.onChanged,
  });

  final Widget marker;
  final TextEditingController controller;
  final String hint;
  final String semanticLabel;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Semantics(
      textField: true,
      label: semanticLabel,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            marker,
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                cursorColor: palette.brand,
                cursorWidth: 2,
                style: RoutbText.copy(14, color: palette.ink),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintText: hint,
                  hintStyle: RoutbText.copy(14, color: palette.muted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
