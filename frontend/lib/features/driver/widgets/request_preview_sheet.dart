import 'package:flutter/material.dart';

import '../../../core/models/trip.dart';
import '../../../core/models/trip_request.dart';
import '../../../core/services/whatsapp_launcher.dart';
import '../../../core/theme/routb_palette.dart';
import '../../../core/theme/routb_text.dart';
import '../../../core/theme/routb_theme.dart';
import '../../../core/widgets/routb_button.dart';
import '../../../core/widgets/routb_card.dart';
import '../../../core/widgets/routb_seats.dart';
import '../../../core/widgets/routb_sheet.dart';
import '../../../core/widgets/route_map.dart';
import 'driver_cards.dart';

/// Abre la hoja de previsualización de ruta para una solicitud de cupo.
///
/// Permite al conductor ver el mapa con las coordenadas reales, el origen,
/// el destino, las paradas confirmadas y la parada que solicita el pasajero,
/// con cálculo de desvío y botones para aceptar o rechazar directamente.
Future<void> showRequestPreviewSheet({
  required BuildContext context,
  required Trip trip,
  required TripRequest request,
  required VoidCallback onAccept,
  required VoidCallback onReject,
}) {
  final waypoints = <String>[
    ...trip.acceptedWaypoints,
    for (final stop in request.stops)
      if (stop.addressText.trim().isNotEmpty) stop.addressText.trim(),
  ];

  final seatsLeft = (trip.availableSeats - request.seatCount).clamp(
    0,
    trip.totalSeats,
  );

  return RoutbSheet.show<void>(
    context: context,
    title: 'Solicitud de ${request.passengerName}',
    subtitle: 'Previsualización del trayecto si aceptas este cupo',
    heightFactor: 0.88,
    body: _RequestPreviewBody(
      trip: trip,
      request: request,
      waypoints: waypoints,
      seatsLeft: seatsLeft,
    ),
    footer: _RequestPreviewFooter(
      onAccept: () {
        Navigator.of(context).pop();
        onAccept();
      },
      onReject: () {
        Navigator.of(context).pop();
        onReject();
      },
    ),
  );
}

class _RequestPreviewBody extends StatelessWidget {
  const _RequestPreviewBody({
    required this.trip,
    required this.request,
    required this.waypoints,
    required this.seatsLeft,
  });

  final Trip trip;
  final TripRequest request;
  final List<String> waypoints;
  final int seatsLeft;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mapa con la ruta completa estimada (incluyendo la parada solicitada)
        ClipRRect(
          borderRadius: BorderRadius.circular(RoutbTheme.radiusCard),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: palette.line),
              borderRadius: BorderRadius.circular(RoutbTheme.radiusCard),
            ),
            child: RouteMap(
              origin: trip.origin,
              destination: trip.destination,
              waypoints: waypoints,
              height: 230,
              interactive: true,
              animateRoute: true,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Información de la ruta y paradas solicitadas
        RoutbCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trayecto estimado',
                style: RoutbText.copy(
                  12,
                  color: palette.muted,
                  weight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.directions_car_rounded,
                    size: 16,
                    color: palette.brand,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${trip.origin} → ${trip.destination}',
                      style: RoutbText.headline(16, color: palette.ink),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${trip.departureDateLabel} · ${trip.departureLabel}',
                style: RoutbText.copy(12, color: palette.muted),
              ),

              if (request.stops.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Text(
                  'Punto de recogida solicitado:',
                  style: RoutbText.copy(
                    12,
                    color: palette.muted,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                for (final stop in request.stops) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.person_pin_circle_rounded,
                          size: 16,
                          color: const Color(0xFFE67E22),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stop.addressText,
                              style: RoutbText.copy(
                                14,
                                color: palette.ink,
                                weight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            DetourBadge(
                              trip: trip,
                              stopAddress: stop.addressText,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ] else ...[
                const SizedBox(height: 8),
                Text(
                  'Sin desvío · Encuentro en: ${trip.meetingPoint.trim().isEmpty ? trip.origin : trip.meetingPoint}',
                  style: RoutbText.copy(13, color: palette.muted),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Tarjeta del pasajero y estado de cupos
        RoutbCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InitialsAvatar(
                    name: request.passengerName,
                    initials: request.initials,
                    size: 44,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.passengerName,
                          style: RoutbText.headline(16, color: palette.ink),
                        ),
                        Text(
                          '${request.seatCount} ${request.seatCount == 1 ? 'cupo solicitado' : 'cupos solicitados'}',
                          style: RoutbText.copy(13, color: palette.muted),
                        ),
                        if (request.hasPhone) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Tel: ${request.passengerPhone}',
                            style: RoutbText.copy(12, color: palette.muted),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (request.hasPhone) ...[
                const SizedBox(height: 10),
                WhatsAppButton(
                  phone: request.passengerPhone,
                  label: 'Escribir por WhatsApp',
                  message:
                      'Hola ${request.passengerName}, te escribo por tu solicitud de cupo en ROUTB para la ruta ${trip.routeLabel}.',
                ),
              ],
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: seatsLeft > 0
                      ? palette.mint.withValues(alpha: 0.12)
                      : palette.amber.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.airline_seat_recline_normal_rounded,
                      size: 15,
                      color: seatsLeft > 0 ? palette.mint : palette.amber,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        seatsLeft > 0
                            ? 'Al aceptar, te quedarán $seatsLeft de ${trip.totalSeats} cupos libres.'
                            : 'Al aceptar, el viaje quedará completo (0 cupos libres).',
                        style: RoutbText.copy(
                          12,
                          color: palette.ink,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RequestPreviewFooter extends StatelessWidget {
  const _RequestPreviewFooter({required this.onAccept, required this.onReject});

  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: RoutbButton(
            label: 'Rechazar',
            icon: Icons.close_rounded,
            variant: RoutbButtonVariant.danger,
            onPressed: onReject,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 3,
          child: RoutbButton(
            label: 'Aceptar cupo',
            icon: Icons.check_rounded,
            variant: RoutbButtonVariant.primary,
            onPressed: onAccept,
          ),
        ),
      ],
    );
  }
}
