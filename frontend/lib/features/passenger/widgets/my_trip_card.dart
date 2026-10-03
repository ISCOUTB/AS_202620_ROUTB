import 'package:flutter/material.dart';

import '../../../core/models/my_request.dart';
import '../../../core/theme/routb_palette.dart';
import '../../../core/theme/routb_text.dart';
import '../../../core/widgets/routb_card.dart';
import '../../../core/widgets/routb_field.dart';
import '../../../core/widgets/routb_seats.dart';

/// Píldora con el estado de la solicitud: confirmada, en espera o cancelada.
class MyTripStatusPill extends StatelessWidget {
  const MyTripStatusPill({required this.request, super.key});

  /// Solicitud cuyo estado se pinta.
  final MyRequest request;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    final (
      Color background,
      Color foreground,
      IconData icon,
    ) = request.isOrphaned
        ? (palette.roseSurface, palette.onRoseSurface, Icons.cancel_rounded)
        : request.isPast
        ? (palette.surface, palette.muted, Icons.check_circle_outline_rounded)
        : request.isConfirmed
        ? (
            palette.mintSurface,
            palette.onMintSurface,
            Icons.check_circle_rounded,
          )
        : (
            palette.amberSurface,
            palette.onAmberSurface,
            Icons.schedule_rounded,
          );

    return RoutbStatusPill(
      label: request.statusLabel,
      background: background,
      foreground: foreground,
      icon: icon,
    );
  }
}

/// Tarjeta fija sobre el buscador cuando el pasajero tiene un viaje en curso.
///
/// Va sobre el listado, y no dentro del hero, por dos razones: el hero ya es
/// alto y en un teléfono de 640 px no cabía otro bloque; y la tarjeta tiene que
/// seguir a la vista mientras se recorre la lista de viajes.
///
/// Aparece incluso con cero resultados, que es el caso que la justifica: al
/// ocupar el último cupo el viaje deja de salir en `GET /trips/`, así que el
/// buscador queda vacío justo cuando más hace falta saber del viaje.
class MyTripCard extends StatelessWidget {
  const MyTripCard({required this.request, required this.onTap, super.key});

  /// Solicitud que se resume.
  final MyRequest request;

  /// Acción al pulsar: abrir el detalle.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final arrival = request.estimatedArrival;

    return RoutbCard(
      onTap: onTap,
      semanticLabel: 'Mi viaje: ${request.routeLabel}. ${request.statusLabel}',
      borderColor: request.isPast
          ? palette.line
          : request.isConfirmed
          ? palette.mint
          : palette.amber,
      borderWidth: 1,
      child: Row(
        children: [
          InitialsAvatar(
            name: request.driverName ?? '?',
            initials: request.driverInitials,
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                MyTripStatusPill(request: request),
                const SizedBox(height: 6),
                // El trayecto cede antes que la hora: en pantallas estrechas es
                // lo que evita que la fila se desborde.
                Flexible(
                  child: Text(
                    request.routeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: RoutbText.headline(15, color: palette.ink),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    '${request.departureDateLabel} · ${request.departureLabel}',
                    if (arrival != null) 'llega ${arrival.label}',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: RoutbText.copy(12, color: palette.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, color: palette.muted),
        ],
      ),
    );
  }
}
