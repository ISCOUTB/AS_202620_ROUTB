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

  final Set<int> _busyRequests = <int>{};

  Future<void> _acceptRequest(TripRequest request) async {
    if (_busyRequests.contains(request.id)) return;
    setState(() => _busyRequests.add(request.id));

    final repository = RoutbScopeDependencies.of(context).trips;
    try {
      final accepted = await repository.accept(request.id);
      final updated = _trip.copyWith(
        availableSeats: (_trip.availableSeats - accepted.seatCount).clamp(
          0,
          _trip.totalSeats,
        ),
        requests: [
          for (final req in _trip.requests)
            if (req.id == accepted.id) accepted else req,
        ],
      );
      setState(() => _trip = updated);
      widget.onChanged(updated);
      if (!mounted) return;
      final free = updated.availableSeats;
      RoutbToast.show(
        context,
        free > 0
            ? 'Aceptaste a ${request.passengerName.split(' ').first} · quedan $free cupos'
            : 'Aceptaste a ${request.passengerName.split(' ').first} · el viaje quedó lleno',
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      RoutbToast.show(context, error.message);
      await _reloadRequests();
    } finally {
      if (mounted) setState(() => _busyRequests.remove(request.id));
    }
  }

  Future<void> _rejectRequest(TripRequest request) async {
    if (_busyRequests.contains(request.id)) return;
    setState(() => _busyRequests.add(request.id));

    final repository = RoutbScopeDependencies.of(context).trips;
    try {
      final rejected = await repository.reject(request.id);
      final availableSeats = request.isAccepted
          ? (_trip.availableSeats + request.seatCount).clamp(
              0,
              _trip.totalSeats,
            )
          : _trip.availableSeats;
      final updated = _trip.copyWith(
        availableSeats: availableSeats,
        requests: [
          for (final req in _trip.requests)
            if (req.id == rejected.id) rejected else req,
        ],
      );
      setState(() => _trip = updated);
      widget.onChanged(updated);
      if (!mounted) return;
      RoutbToast.show(context, 'Solicitud rechazada');
    } on ApiException catch (error) {
      if (!mounted) return;
      RoutbToast.show(context, error.message);
      await _reloadRequests();
    } finally {
      if (mounted) setState(() => _busyRequests.remove(request.id));
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
    final accepted = _trip.requests.accepted;
    final acceptedSeatCount = accepted.fold<int>(
      0,
      (total, request) => total + request.seatCount,
    );

    final (Color pillBackground, Color pillForeground) = switch (phase) {
      TripPhase.onCourse => (palette.mintSurface, palette.onMintSurface),
      TripPhase.cancelled => (palette.roseSurface, palette.onRoseSurface),
      TripPhase.completed => (palette.surface, palette.muted),
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
                              subtitle:
                                  '${_trip.departureDateLabel} · salida ${_trip.departureLabel}',
                              reached: phase == TripPhase.onCourse,
                            ),
                            TimelineStop(
                              title: _trip.destination,
                              subtitle: 'Destino final',
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
                        const SizedBox(height: 10),
                        Text(
                          'Encuentro: ${_trip.meetingPoint}',
                          style: RoutbText.copy(13, color: palette.ink),
                        ),
                        const SizedBox(height: 4),
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

                  if (_trip.requests.pending.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    RoutbCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RoutbCardHeader(
                            title: 'Solicitudes pendientes',
                            count: _trip.requests.pending.length,
                          ),
                          for (final req in _trip.requests.pending)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: RequestTile(
                                request: req,
                                trip: _trip,
                                busy: _busyRequests.contains(req.id),
                                onAccept: () => _acceptRequest(req),
                                onReject: () => _rejectRequest(req),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],

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
                                        for (final stop in request.stops)
                                          Text(
                                            '${stop.stopSequence == null ? '' : '${stop.stopSequence}. '}${stop.addressText} · ${stop.seats} ${stop.seats == 1 ? 'persona' : 'personas'}',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
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
