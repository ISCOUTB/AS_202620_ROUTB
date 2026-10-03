import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/dependencies.dart';
import '../../../core/models/trip.dart';
import '../../../core/models/trip_request.dart';
import '../../../core/models/trip_status.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/routb_palette.dart';
import '../../../core/theme/routb_text.dart';
import '../../../core/widgets/routb_button.dart';
import '../../../core/widgets/routb_card.dart';
import '../../../core/widgets/routb_field.dart';
import '../../../core/widgets/routb_live_pill.dart';
import '../../../core/widgets/routb_route.dart';
import '../../../core/widgets/routb_seats.dart';
import '../../../core/widgets/routb_toast.dart';
import '../widgets/driver_cards.dart';
import '../widgets/routb_trip_map.dart';

/// Detalle de una ruta del conductor.
///
/// Toda la información viene del backend: el trayecto, la hora, los pasajeros con
/// cupo confirmado y sus teléfonos, y el estado de cada plaza.
///
/// Lo que **no** hay es un «Iniciar viaje»: el backend no guarda que un recorrido
/// esté en marcha ni la posición del carro, así que simularlo daría una
/// sensación de seguimiento que el sistema no tiene. El mapa muestra el trayecto
/// estimado y la hora real de salida.
class RouteDetailScreen extends StatefulWidget {
  const RouteDetailScreen({
    required this.trip,
    required this.onChanged,
    required this.onCancelled,
    super.key,
  });

  /// Ruta que se muestra.
  final Trip trip;

  /// Se avisa cuando la ruta cambió en el servidor.
  final ValueChanged<Trip> onChanged;

  /// Se avisa cuando la ruta se canceló, para sacarla de la lista del conductor.
  final VoidCallback onCancelled;

  @override
  State<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends State<RouteDetailScreen> {
  late Trip _trip = widget.trip;
  bool _busy = false;
  bool _loadedRequests = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // `GET /trips/my-trips` ya incluye las solicitudes; solo hace falta pedirlas
    // aparte si llegaron vacías, por ejemplo cuando se abre desde otra pantalla.
    if (!_loadedRequests) {
      _loadedRequests = true;
      if (_trip.requests.isEmpty) unawaited(_reloadRequests());
    }
  }

  Future<void> _reloadRequests() async {
    final repository = RoutbScopeDependencies.of(context).trips;
    try {
      final requests = await repository.listRequests(_trip.id);
      if (!mounted) return;
      setState(() => _trip = _trip.copyWith(requests: requests));
      widget.onChanged(_trip);
    } on ApiException catch (error) {
      if (!mounted) return;
      RoutbToast.show(context, error.message);
    }
  }

  Future<void> _cancel() async {
    final accepted = _trip.requests.accepted.fold<int>(
      0,
      (total, request) => total + request.seatCount,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final palette = dialogContext.palette;
        return AlertDialog(
          title: const Text('¿Cancelar esta ruta?'),
          content: Text(
            accepted > 0
                ? 'Tienes $accepted ${accepted == 1 ? 'pasajero confirmado' : 'pasajeros confirmados'}. '
                      'La ruta dejará de aparecer en el listado y no se puede volver a activar.'
                : 'La ruta dejará de aparecer en el listado de los pasajeros. '
                      'No se puede volver a activar.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Mantener ruta'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                'Cancelar ruta',
                style: TextStyle(color: palette.rose),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await RoutbScopeDependencies.of(context).trips.cancel(_trip.id);
      if (!mounted) return;
      widget.onCancelled();
      Navigator.of(context).pop();
      RoutbToast.show(context, 'Ruta cancelada: ya no la ven los pasajeros');
    } on ApiException catch (error) {
      if (!mounted) return;
      RoutbToast.show(context, error.message);
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final phase = _trip.phaseAt(DateTime.now());
    final arrival = _trip.estimatedArrival;
    final accepted = _trip.requests.accepted;
    final acceptedSeatCount = accepted.fold<int>(
      0,
      (total, request) => total + request.seatCount,
    );

    final (Color pillBackground, Color pillForeground) = switch (phase) {
      TripPhase.onCourse => (palette.mintSurface, palette.onMintSurface),
      TripPhase.cancelled => (palette.roseSurface, palette.onRoseSurface),
      TripPhase.scheduled => (palette.amberSurface, palette.onAmberSurface),
    };

    return Scaffold(
      backgroundColor: palette.background,
      // Sin boton de recarga: la pantalla ya se actualiza sola al abrirse y el
      // unico dato que recarga (las solicitudes) no cambia mientras se mira.
      appBar: AppBar(title: const Text('Detalle de la ruta')),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
                children: [
                  RoutbTripMap(
                    trip: _trip,
                    height: 220,
                    interactive: true,
                    showPhase: false,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          phase == TripPhase.onCourse
                              ? 'Trayecto en marcha'
                              : 'Trayecto estimado',
                          style: RoutbText.copy(12, color: palette.muted),
                        ),
                      ),
                      LivePill(phase: phase, onDark: false),
                    ],
                  ),

                  const SizedBox(height: 16),
                  RoutbCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _trip.routeLabel,
                          style: RoutbText.headline(20, color: palette.ink),
                        ),
                        const SizedBox(height: 14),
                        DashedTimeline(
                          stops: [
                            TimelineStop(
                              title: _trip.origin,
                              subtitle: 'Salida ${_trip.departureLabel}',
                              reached: phase == TripPhase.onCourse,
                            ),
                            TimelineStop(
                              title: _trip.destination,
                              subtitle: arrival == null
                                  ? 'Sin hora de llegada estimada'
                                  : 'Llegada estimada ${arrival.label}',
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            RoutbStatusPill(
                              label: phase.label,
                              background: pillBackground,
                              foreground: pillForeground,
                            ),
                            const SizedBox(width: 10),
                            const Spacer(),
                            Flexible(
                              child: Text(
                                '${_trip.availableSeats} de ${_trip.totalSeats} cupos libres',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                                style: RoutbText.copy(13, color: palette.ink),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),
                  RoutbCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const RoutbCardHeader(title: 'Cupos'),
                        Center(child: OccupiedSeatsCard(trip: _trip)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),
                  RoutbCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RoutbCardHeader(
                          title: 'Pasajeros confirmados',
                          count: acceptedSeatCount,
                        ),
                        if (_busy && accepted.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          )
                        else if (accepted.isEmpty)
                          const RoutbEmptyState(
                            message:
                                'Todavía no hay pasajeros con cupo confirmado.',
                          )
                        else
                          for (final request in accepted)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  InitialsAvatar(
                                    name: request.passengerName,
                                    initials: request.initials,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          request.passengerName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: RoutbText.headline(
                                            15,
                                            color: palette.ink,
                                          ),
                                        ),
                                        if (request.hasPhone)
                                          Text(
                                            request.passengerPhone,
                                            style: RoutbText.copy(
                                              12,
                                              color: palette.muted,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (request.hasPhone)
                                    Icon(
                                      Icons.phone_rounded,
                                      size: 16,
                                      color: palette.muted,
                                    ),
                                ],
                              ),
                            ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  RoutbButton(
                    label: 'Cancelar ruta',
                    icon: Icons.close_rounded,
                    variant: RoutbButtonVariant.danger,
                    busy: _busy,
                    onPressed: _cancel,
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
