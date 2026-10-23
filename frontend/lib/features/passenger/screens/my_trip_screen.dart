import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/dependencies.dart';
import '../../../core/models/my_request.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/routb_palette.dart';
import '../../../core/theme/routb_text.dart';
import '../../../core/services/whatsapp_launcher.dart';
import '../../../core/widgets/routb_button.dart';
import '../../../core/widgets/routb_card.dart';
import '../../../core/widgets/routb_route.dart';
import '../../../core/widgets/routb_seats.dart';
import '../../../core/widgets/routb_toast.dart';
import '../../../core/widgets/route_map.dart';
import '../widgets/my_trip_card.dart';

/// Detalle del viaje que el pasajero tiene en curso.
///
/// Aquí vive toda la información de la solicitud: el trayecto, la hora, los
/// cupos que quedan, el conductor con su teléfono y el botón para cancelar.
///
/// El botón solo aparece si el backend expone `DELETE /requests/{id}`. Contra un
/// despliegue viejo la retirada no es posible, y es mejor decirlo con claridad
/// que dejar un botón que revienta.
class MyTripScreen extends StatefulWidget {
  const MyTripScreen({
    required this.request,
    required this.onWithdrawn,
    super.key,
  });

  /// Solicitud que se muestra.
  final MyRequest request;

  /// Se avisa cuando la solicitud se retiró, para quitar la tarjeta del
  /// buscador.
  final VoidCallback onWithdrawn;

  @override
  State<MyTripScreen> createState() => _MyTripScreenState();
}

class _MyTripScreenState extends State<MyTripScreen> {
  late MyRequest _request = widget.request;
  bool _busy = false;
  bool _refreshing = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    if (!_request.isActive) return;
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted && !_busy && !_refreshing) {
        unawaited(_reloadRequest(silent: true));
      }
    });
  }

  Future<void> _reloadRequest({bool silent = false}) async {
    if (_refreshing) return;
    if (!silent) setState(() => _refreshing = true);
    try {
      final requests = await RoutbScopeDependencies.of(context).trips
          .myRequests();
      if (!mounted) return;
      final current = requests.firstWhere(
        (r) => r.id == _request.id,
        orElse: () => _request,
      );
      if (current != _request) {
        setState(() => _request = current);
        if (!current.isActive) {
          _pollTimer?.cancel();
        }
      }
    } catch (_) {
      // Ignorar errores de sondeo en segundo plano
    } finally {
      if (mounted && !silent) {
        setState(() => _refreshing = false);
      }
    }
  }

  Future<void> _withdraw() async {
    if (_busy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Cancelar este cupo?'),
        content: Text(
          _request.isConfirmed
              ? 'Vas a liberar el cupo confirmado con '
                    '${_request.driverName ?? 'el conductor'}. '
                    'Queda libre para otra persona.'
              : 'Tu solicitud al conductor se descarta. '
                    'Podrás volver a pedir cupo en otro viaje.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Mantener cupo'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Cancelar cupo',
              style: TextStyle(color: dialogContext.palette.rose),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await RoutbScopeDependencies.of(context).trips
          .withdrawRequest(_request.id);
      if (!mounted) return;
      widget.onWithdrawn();
      Navigator.of(context).pop();
      RoutbToast.show(context, 'Reserva cancelada');
    } on ApiException catch (error) {
      if (!mounted) return;
      RoutbToast.show(context, error.message);
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: const Text('Mi viaje'),
        actions: [
          IconButton(
            icon: _refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar',
            onPressed: () => _reloadRequest(silent: false),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: RefreshIndicator(
                onRefresh: () => _reloadRequest(silent: false),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
                  children: [
                    RouteMap(
                      origin: _request.origin,
                      destination: _request.destination,
                      waypoints: _request.waypoints,
                      height: 200,
                      interactive: true,
                    ),
                    const SizedBox(height: 12),
                    Center(child: MyTripStatusPill(request: _request)),
                    const SizedBox(height: 16),

                    RoutbCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _request.routeLabel,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: RoutbText.headline(20, color: palette.ink),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${_request.departureDateLabel} · salida ${_request.departureLabel}',
                            style: RoutbText.copy(13, color: palette.muted),
                          ),
                          const SizedBox(height: 14),
                          DashedTimeline(
                            stops: [
                              TimelineStop(
                                title: _request.origin,
                                subtitle: 'Salida ${_request.departureLabel}',
                              ),
                              for (
                                var i = 0;
                                i < _request.waypoints.length;
                                i++
                              )
                                TimelineStop(
                                  title: _request.waypoints[i],
                                  subtitle: _request.waypoints.length == 1
                                      ? 'Parada de recogida'
                                      : 'Parada de recogida ${i + 1}',
                                ),
                              TimelineStop(
                                title: _request.destination,
                                subtitle: 'Destino final',
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              // El texto largo cede antes que el contador: en
                              // pantallas estrechas es lo que evita el desborde.
                              Flexible(
                                child: Text(
                                  _request.isConfirmed
                                      ? 'Tienes ${_request.seatCount} ${_request.seatCount == 1 ? 'cupo confirmado' : 'cupos confirmados'}'
                                      : '${_request.seatCount} ${_request.seatCount == 1 ? 'cupo en espera' : 'cupos en espera'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: RoutbText.copy(13, color: palette.ink),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${_request.availableSeats} de '
                                '${_request.totalSeats} libres',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                                style: RoutbText.copy(13, color: palette.muted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Encuentro: ${_request.meetingPoint}',
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
                          const RoutbCardHeader(title: 'Tu conductor'),
                          Row(
                            children: [
                              InitialsAvatar(
                                name: _request.driverName ?? '?',
                                initials: _request.driverInitials,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _request.hasDriverName
                                          ? _request.driverName!
                                          : 'Conductor sin asignar',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: RoutbText.headline(
                                        15,
                                        color: palette.ink,
                                      ),
                                    ),
                                    if (_request.hasDriverPhone)
                                      Text(
                                        _request.driverPhone!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: RoutbText.copy(
                                          12,
                                          color: palette.muted,
                                        ),
                                      )
                                    else
                                      Text(
                                        'Teléfono no disponible',
                                        style: RoutbText.copy(
                                          12,
                                          color: palette.muted,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (_request.hasDriverPhone &&
                                  _request.isConfirmed)
                                WhatsAppButton(
                                  phone: _request.driverPhone!,
                                  message:
                                      'Hola ${_request.driverName ?? ''}, te contacto desde ROUTB sobre el viaje ${_request.routeLabel} (${_request.departureLabel}).',
                                  compact: true,
                                )
                              else if (_request.hasDriverPhone)
                                Icon(
                                  Icons.phone_rounded,
                                  size: 18,
                                  color: palette.muted,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    if (_request.isOrphaned) ...[
                      const SizedBox(height: 14),
                      RoutbCard(
                        borderColor: palette.rose,
                        borderWidth: 1,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 18,
                              color: palette.rose,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'El conductor canceló la ruta. Tu solicitud ya no '
                                'tiene sentido: retírala para buscar otro viaje.',
                                style: RoutbText.copy(13, color: palette.ink),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                    if (_request.canWithdraw)
                      RoutbButton(
                        label: 'Cancelar',
                        icon: Icons.close_rounded,
                        variant: RoutbButtonVariant.danger,
                        busy: _busy,
                        onPressed: _withdraw,
                      )
                    else
                      // `GET /requests/me` existe pero el retiro no: casi siempre es
                      // un despliegue con el backend sin actualizar.
                      RoutbButton(
                        label: 'Cancelar',
                        variant: RoutbButtonVariant.secondary,
                        expand: false,
                        height: 44,
                        onPressed: null,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
