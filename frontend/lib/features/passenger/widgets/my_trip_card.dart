import 'package:flutter/material.dart';

import '../../../core/models/my_request.dart';
import '../../../core/models/trip_status.dart';
import '../../../core/theme/routb_motion.dart';
import '../../../core/theme/routb_palette.dart';
import '../../../core/theme/routb_text.dart';
import '../../../core/theme/routb_theme.dart';
import '../../../core/widgets/routb_card.dart';
import '../../../core/widgets/routb_field.dart';
import '../../../core/widgets/routb_freshness.dart';
import '../../../core/widgets/routb_seats.dart';
import '../../../core/widgets/routb_vehicle_badge.dart';

/// Píldora con el estado de la solicitud: confirmada, en espera o cancelada.
///
/// La transición entre estados se anima con [AnimatedSwitcher], de modo que
/// cuando el sondeo o un push cambian la solicitud de pendiente a aceptada el
/// cambio se percibe aunque el resto de la tarjeta no se mueva.
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
        : request.isCompleted
        ? (palette.surface, palette.muted, Icons.check_circle_outline_rounded)
        : request.isHistoryCancelled
        ? (palette.roseSurface, palette.onRoseSurface, Icons.cancel_rounded)
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

    return AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : RoutbMotion.toast,
      switchInCurve: RoutbMotion.standard,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: RoutbStatusPill(
        key: ValueKey<String>(request.statusLabel),
        label: request.statusLabel,
        background: background,
        foreground: foreground,
        icon: icon,
      ),
    );
  }
}

/// Mensaje explicativo que acompaña a la píldora de estado.
String myTripStatusMessage(MyRequest request) {
  if (request.isOrphaned) {
    return 'El conductor canceló la ruta. Busca otro viaje.';
  }
  if (request.status == SeatRequestStatus.rejected) {
    return 'El conductor no aceptó tu solicitud. Puedes buscar otro viaje.';
  }
  if (request.status == SeatRequestStatus.expired ||
      (request.isPending && request.isPast)) {
    return 'La solicitud venció sin respuesta del conductor.';
  }
  if (request.isCompleted) {
    return 'El viaje terminó y quedó guardado en tu historial.';
  }
  if (request.isConfirmed) {
    return 'Solicitud confirmada, espera al conductor en el punto de encuentro.';
  }
  if (request.isPending) {
    return 'El conductor recibió tu solicitud. Te avisaremos cuando responda.';
  }
  if (request.status == SeatRequestStatus.cancelled) {
    return 'Otra solicitud fue aceptada y esta quedó sin cupo.';
  }
  return 'El conductor no aceptó tu solicitud. Puedes buscar otro viaje.';
}

/// Píldora de estado con su explicación y, si hay sondeo, su frescura.
class MyTripStatusSummary extends StatelessWidget {
  const MyTripStatusSummary({
    required this.request,
    this.lastUpdated,
    this.center = false,
    super.key,
  });

  /// Solicitud cuyo estado se describe.
  final MyRequest request;

  /// Momento del último sondeo exitoso. `null` oculta el indicador.
  final DateTime? lastUpdated;

  /// `true` para centrar el bloque en el detalle.
  final bool center;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final alignment = center ? TextAlign.center : TextAlign.start;
    final crossAxisAlignment = center
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: crossAxisAlignment,
      children: [
        MyTripStatusPill(request: request),
        const SizedBox(height: 5),
        Text(
          myTripStatusMessage(request),
          textAlign: alignment,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: RoutbText.copy(12, color: palette.muted, height: 1.35),
        ),
        if (lastUpdated != null) ...[
          const SizedBox(height: 5),
          RoutbFreshnessLabel(lastUpdated: lastUpdated!),
        ],
      ],
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
  const MyTripCard({
    required this.request,
    this.onTap,
    this.onCancel,
    this.busy = false,
    this.lastUpdated,
    super.key,
  });

  /// Solicitud que se resume.
  final MyRequest request;

  /// Acción al pulsar: abrir el detalle. `null` deja la tarjeta solo de
  /// consulta, como en el historial.
  final VoidCallback? onTap;

  /// Cancelación rápida desde la tarjeta. `null` oculta el botón.
  final VoidCallback? onCancel;

  /// `true` mientras la cancelación está en curso.
  final bool busy;

  /// Momento del último sondeo exitoso, si el sondeo está activo.
  final DateTime? lastUpdated;

  /// Solo las solicitudes pendientes y retirables se cancelan desde aquí.
  bool get _canCancel =>
      request.isPending && request.canWithdraw && !request.isPast;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return RoutbCard(
      onTap: onTap,
      semanticLabel: 'Mi viaje: ${request.routeLabel}. ${request.statusLabel}',
      borderColor: request.isPast
          ? palette.line
          : request.isConfirmed
          ? palette.mint
          : palette.amber,
      borderWidth: request.isPast ? 1 : 1.5,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              InitialsAvatar(
                name: request.driverName ?? '?',
                initials: request.driverInitials,
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MyTripStatusSummary(
                      request: request,
                      lastUpdated: lastUpdated,
                    ),
                    const SizedBox(height: 6),
                    // El trayecto cede antes que la hora: en pantallas estrechas
                    // es lo que evita que la fila se desborde.
                    Flexible(
                      child: Text(
                        request.routeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RoutbText.headline(15, color: palette.ink),
                      ),
                    ),
                    if (request.hasDriverName) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Conductor: ${request.driverName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RoutbText.copy(12, color: palette.muted),
                      ),
                    ],
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 13,
                          color: palette.muted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${request.departureDateLabel} · ${request.departureLabel}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: RoutbText.copy(12, color: palette.muted),
                          ),
                        ),
                      ],
                    ),
                    // La ficha del vehículo es privada: solo se muestra cuando
                    // el cupo quedó confirmado, aunque el backend ya la filtre.
                    if (request.isConfirmed && request.hasVehicleInfo) ...[
                      const SizedBox(height: 6),
                      RoutbVehicleBadge(
                        info: request.vehicleInfo!,
                        dense: true,
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: palette.brand,
                  ),
                ),
              ],
            ],
          ),
          // G5: cancelar sin abrir el detalle, solo para lo que todavía se
          // puede retirar. El diálogo y la llamada siguen viviendo en la
          // pantalla, que es quien actualiza la lista.
          if (onCancel != null && _canCancel) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Semantics(
                button: true,
                label: 'Cancelar esta solicitud',
                child: TextButton.icon(
                  onPressed: busy ? null : onCancel,
                  style: TextButton.styleFrom(
                    foregroundColor: palette.rose,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        RoutbTheme.radiusPill,
                      ),
                    ),
                  ),
                  icon: busy
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: palette.rose,
                          ),
                        )
                      : const Icon(Icons.close_rounded, size: 16),
                  label: Text(
                    'Cancelar solicitud',
                    style: RoutbText.copy(
                      12,
                      color: palette.rose,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
