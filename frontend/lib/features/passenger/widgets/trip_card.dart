import 'package:flutter/material.dart';

import '../../../core/models/trip.dart';
import '../../../core/theme/routb_palette.dart';
import '../../../core/theme/routb_text.dart';
import '../../../core/widgets/routb_card.dart';
import '../../../core/widgets/routb_route.dart';
import '../../../core/widgets/routb_seats.dart';

/// `.tk`: tarjeta de un viaje disponible.
///
/// Muestra el conductor, la hora, el trayecto con el punto recorriéndolo, los
/// cupos y el botón de reserva, que cambia de estado según lo que haya pasado
/// con la solicitud.
///
/// El diseño original ponía aquí una valoración («4.8 · 12 reseñas»). ROUTB no
/// tiene entidad de reseñas, así que en su lugar se muestra la **llegada
/// estimada**, que sí se puede calcular y le sirve a quien está buscando cupo.
class TripCard extends StatelessWidget {
  const TripCard({
    required this.trip,
    this.onReserve,
    this.isNew = false,
    this.index = 0,
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

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final state = trip.bookingState;
    final arrival = trip.estimatedArrival;
    final driverName = trip.hasDriverName
        ? trip.driverName!
        : 'Conductor ROUTB';

    return RoutbCard(
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(name: driverName, initials: trip.driverInitials),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            driverName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: RoutbText.headline(15, color: palette.ink),
                          ),
                        ),
                        if (isNew) ...[
                          const SizedBox(width: 8),
                          RoutbBadge(
                            text: 'Nuevo',
                            dense: true,
                            background: palette.mint,
                            foreground: palette.onMint,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      arrival == null
                          ? 'Sin hora de llegada estimada'
                          : 'Llegada estimada ${arrival.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RoutbText.copy(12, color: palette.muted),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    trip.departureClockLabel,
                    style: RoutbText.headline(
                      26,
                      color: palette.ink,
                      height: 1,
                    ),
                  ),
                  Text(
                    trip.departureMeridiem,
                    style: RoutbText.copy(11, color: palette.muted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          TravelPath(origin: trip.origin, destination: trip.destination),
          const SizedBox(height: 16),
          const DashedDivider(),
          const SizedBox(height: 14),
          Row(
            children: [
              // Los puntos y el texto se reparten el espacio sobrante; el botón
              // conserva el suyo y recorta su etiqueta si no cabe.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SeatDots(
                      total: trip.totalSeats,
                      available: trip.availableSeats,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${trip.availableSeats}/${trip.totalSeats} cupos libres',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RoutbText.copy(12, color: palette.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _ReserveButton(state: state, onPressed: onReserve),
                ),
              ),
            ],
          ),
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
        Colors.white,
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
      SeatRequestState.full => ('Sin cupos', palette.surface, palette.muted),
      SeatRequestState.unavailable => (
        'No disponible',
        palette.surface,
        palette.muted,
      ),
    };

    final description = switch (state) {
      SeatRequestState.available =>
        'Elige entre 1 y 4 cupos para solicitar. El conductor decide si acepta el grupo completo.',
      SeatRequestState.requested =>
        'La solicitud está en espera. No se puede retirar desde la app.',
      SeatRequestState.confirmed =>
        'El conductor confirmó tu cupo en este viaje.',
      SeatRequestState.full => 'Este viaje ya no tiene cupos disponibles.',
      SeatRequestState.unavailable => 'Este viaje ya no está activo.',
    };

    return Semantics(
      button: state.isActionable,
      enabled: state.isActionable,
      label: description,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: state.isActionable ? onPressed : null,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
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
    super.key,
  });

  final TextEditingController origin;
  final TextEditingController destination;
  final ValueChanged<String> onOriginChanged;
  final ValueChanged<String> onDestinationChanged;

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
