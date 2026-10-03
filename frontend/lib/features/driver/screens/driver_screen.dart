import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/dependencies.dart';
import '../../../core/models/initials.dart';
import '../../../core/models/trip.dart';
import '../../../core/models/trip_request.dart';
import '../../../core/models/user_role.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/routb_palette.dart';
import '../../../core/theme/routb_text.dart';
import '../../../core/theme/routb_theme.dart';
import '../../../core/widgets/routb_anim.dart';
import '../../../core/widgets/routb_button.dart';
import '../../../core/widgets/routb_card.dart';
import '../../../core/widgets/routb_hero.dart';
import '../../../core/widgets/routb_seats.dart';
import '../../../core/widgets/routb_toast.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/screens/auth_flow.dart';
import '../../trips/data/trip_repository.dart';
import '../state/driver_state.dart';
import '../widgets/driver_cards.dart';
import '../widgets/publish_route_sheet.dart';
import '../widgets/routb_trip_map.dart';
import 'route_detail_screen.dart';

/// Cuánto sube el cuerpo de la pantalla sobre el hero del conductor.
///
/// Flutter no admite margen negativo, así que el solapamiento se hace
/// desplazando el cuerpo. El hero reserva este hueco en su padding inferior
/// (más 16 px de aire) y el cuerpo lo sube exactamente esta misma cantidad:
/// si divergieran, el contenido se montaría sobre el mapa o quedaría un hueco.
const double _bodyOverlap = 12;

/// Modo conductor: publica rutas, responde solicitudes y sigue las que tiene.
///
/// El hero muestra siempre la ruta seleccionada: al tocar una tarjeta de «Mis
/// rutas» cambian el mapa, la hora y los cupos. Debajo viven las dos tarjetas
/// del diseño.
class DriverScreen extends StatefulWidget {
  const DriverScreen({required this.account, super.key});

  /// Cuenta que inició sesión.
  final Account account;

  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {
  DriverState _state = const DriverState(status: DriverStatus.loading);
  final Set<int> _busyRequests = <int>{};
  int? _highlightedTripId;
  bool _asked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // La primera carga se pide desde aquí y no desde `initState`: el
    // repositorio se lee del `RoutbScopeDependencies`, y buscar un inherited
    // widget antes de que `initState` termine lanza una aserción que deja la
    // pantalla sin pintar.
    if (_asked) return;
    _asked = true;
    unawaited(_load());
  }

  TripRepository get _trips => RoutbScopeDependencies.of(context).trips;

  Future<void> _load() async {
    try {
      final mine = await _trips.listMine();
      // Cada viaje trae sus propias solicitudes en el payload; de todos modos se
      // pide el detalle de los que tengan alguna, por si el conductor publicó
      // mientras la app estaba abierta.
      final enriched = <Trip>[
        for (final trip in mine)
          if (trip.requests.isEmpty)
            trip.copyWith(requests: await _trips.listRequests(trip.id))
          else
            trip,
      ];

      if (!mounted) return;
      setState(() {
        _state = DriverState(
          status: DriverStatus.ready,
          trips: enriched,
          selected: enriched.firstOrNull,
        );
      });
    } on Exception catch (error, stack) {
      logFailure('la carga de rutas', error, stack);
      if (!mounted) return;
      setState(
        () => _state = DriverState(
          status: DriverStatus.failed,
          errorMessage: describeFailure(error),
        ),
      );
    }
  }

  /// Sustituye una ruta de la lista por una versión actualizada.
  void _replaceTrip(Trip updated) {
    final trips = _state.trips
        .map((trip) => trip.id == updated.id ? updated : trip)
        .toList(growable: false);
    final selected = _state.selected?.id == updated.id
        ? updated
        : _state.selected;

    setState(() => _state = _state.copyWith(trips: trips, selected: selected));
  }

  Future<void> _accept(Trip trip, TripRequest request) async {
    if (_busyRequests.contains(request.id)) return;
    setState(() => _busyRequests.add(request.id));

    try {
      final accepted = await _trips.accept(request.id);
      final updated = trip.copyWith(
        availableSeats: (trip.availableSeats - accepted.seatCount)
            .clamp(0, trip.totalSeats),
        requests: _replaceRequest(trip.requests, accepted),
      );
      _replaceTrip(updated);
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
      await _refreshRequests(trip);
    } finally {
      if (mounted) setState(() => _busyRequests.remove(request.id));
    }
  }

  Future<void> _reject(Trip trip, TripRequest request) async {
    if (_busyRequests.contains(request.id)) return;
    setState(() => _busyRequests.add(request.id));

    try {
      final rejected = await _trips.reject(request.id);
      // Si estaba confirmada, el backend devuelve el cupo al viaje.
      final availableSeats = request.isAccepted
          ? (trip.availableSeats + request.seatCount)
              .clamp(0, trip.totalSeats)
          : trip.availableSeats;
      _replaceTrip(
        trip.copyWith(
          availableSeats: availableSeats,
          requests: _replaceRequest(trip.requests, rejected),
        ),
      );
      if (!mounted) return;
      RoutbToast.show(context, 'Solicitud rechazada');
    } on ApiException catch (error) {
      if (!mounted) return;
      RoutbToast.show(context, error.message);
      await _refreshRequests(trip);
    } finally {
      if (mounted) setState(() => _busyRequests.remove(request.id));
    }
  }

  Future<void> _refreshRequests(Trip trip) async {
    try {
      final requests = await _trips.listRequests(trip.id);
      if (!mounted) return;
      _replaceTrip(trip.copyWith(requests: requests));
    } on ApiException {
      // Se deja la vista como está: el siguiente refresco lo corrige.
    }
  }

  Future<void> _confirmCancel(Trip trip) async {
      final accepted = trip.requests.accepted.fold<int>(
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
                ? 'Tienes $accepted ${accepted == 1 ? 'pasajero' : 'pasajeros'} '
                      'confirmado${accepted == 1 ? '' : 's'}. Al cancelar la ruta '
                      'dejará de aparecer en el listado y no se puede volver a '
                      'activar.'
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

    try {
      await _trips.cancel(trip.id);
      if (!mounted) return;
      final remaining = _state.trips
          .where((item) => item.id != trip.id)
          .toList(growable: false);
      setState(() {
        _state = _state.copyWith(
          trips: remaining,
          selected: _state.selected?.id == trip.id
              ? remaining.firstOrNull
              : null,
        );
      });
      RoutbToast.show(context, 'Ruta cancelada: ya no la ven los pasajeros');
    } on ApiException catch (error) {
      if (!mounted) return;
      RoutbToast.show(context, error.message);
    }
  }

  Future<void> _openPublishSheet() async {
    final draft = await showPublishRouteSheet(
      context: context,
      driverName: widget.account.name,
      driverInitials: initialsOf(widget.account.name),
    );
    if (draft == null || !mounted) return;

    try {
      final published = await _trips.publish(
        origin: draft.origin,
        destination: draft.destination,
        departureTime: draft.departure.label,
        seats: draft.seats,
      );
      if (!mounted) return;
      setState(() {
        _highlightedTripId = published.id;
        _state = _state.copyWith(
          status: DriverStatus.ready,
          trips: <Trip>[published, ..._state.trips],
          selected: published,
        );
      });
      RoutbToast.show(context, 'Ruta publicada. Ya la ven los pasajeros');
    } on ApiException catch (error) {
      if (!mounted) return;
      RoutbToast.show(context, error.message);
    }
  }

  Future<void> _logout() async {
    await RoutbScopeDependencies.of(context).auth.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      RoutbPageRoute<void>(child: const AuthFlow()),
      (route) => false,
    );
    RoutbToast.show(context, 'Cerraste sesión');
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.background,
      floatingActionButton: _state.status == DriverStatus.ready
          ? _NewRouteButton(onPressed: _openPublishSheet)
          : null,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: RoutbTheme.contentMaxWidth,
                ),
                child: switch (_state.status) {
                  DriverStatus.loading => const _LoadingBody(),
                  DriverStatus.failed => _FailedBody(
                    message: _state.errorMessage ?? 'Algo salió mal.',
                    onRetry: _load,
                  ),
                  DriverStatus.ready => _Body(
                    account: widget.account,
                    state: _state,
                    busyRequests: _busyRequests,
                    highlightedTripId: _highlightedTripId,
                    onSelect: (trip) => setState(
                      () => _state = _state.copyWith(selected: trip),
                    ),
                    onAccept: _accept,
                    onReject: _reject,
                    onCancel: _confirmCancel,
                    onOpenDetail: _openDetail,
                    onLogout: _logout,
                    onRefresh: _load,
                  ),
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openDetail(Trip trip) async {
    await Navigator.of(context).push(
      RoutbPageRoute<void>(
        child: RouteDetailScreen(
          trip: trip,
          onChanged: (updated) => _replaceTrip(updated),
          onCancelled: () {
            final remaining = _state.trips
                .where((item) => item.id != trip.id)
                .toList(growable: false);
            setState(() {
              _state = _state.copyWith(
                trips: remaining,
                selected: _state.selected?.id == trip.id
                    ? remaining.firstOrNull
                    : null,
              );
            });
          },
        ),
      ),
    );
    if (mounted) await _load();
  }
}

extension on List<Trip> {
  Trip? get firstOrNull => isEmpty ? null : first;
}

List<TripRequest> _replaceRequest(
  List<TripRequest> requests,
  TripRequest updated,
) => [
  for (final request in requests)
    if (request.id == updated.id) updated else request,
];

/// Cuerpo listo del modo conductor.
class _Body extends StatelessWidget {
  const _Body({
    required this.account,
    required this.state,
    required this.busyRequests,
    required this.highlightedTripId,
    required this.onSelect,
    required this.onAccept,
    required this.onReject,
    required this.onCancel,
    required this.onOpenDetail,
    required this.onLogout,
    required this.onRefresh,
  });

  final Account account;
  final DriverState state;
  final Set<int> busyRequests;
  final int? highlightedTripId;
  final ValueChanged<Trip> onSelect;
  final void Function(Trip trip, TripRequest request) onAccept;
  final void Function(Trip trip, TripRequest request) onReject;
  final ValueChanged<Trip> onCancel;
  final ValueChanged<Trip> onOpenDetail;
  final VoidCallback onLogout;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: HeroSection(
              userName: account.name,
              role: UserRole.driver,
              trip: state.selected,
              onLogout: onLogout,
            ),
          ),
          // El cuerpo queda ligeramente separado del hero para que las
          // secciones respiren sin cambiar la posición ni el tamaño del hero.
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
            sliver: SliverToBoxAdapter(
              child: Transform.translate(
                offset: const Offset(0, 12),
                child: Column(
                  children: [
                    RoutbCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RoutbCardHeader(
                            title: 'Solicitudes',
                            count: state.pendingRequestCount,
                          ),
                          if (state.tripsWithPendingRequests.isEmpty)
                            const RoutbEmptyState(
                              message:
                                  'Sin solicitudes por ahora. Te avisamos '
                                  'cuando llegue una.',
                            )
                          else
                            for (final pendingTrip
                                in state.tripsWithPendingRequests)
                              for (final request
                                  in pendingTrip.requests.pending)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: RequestTile(
                                    request: request,
                                    trip: pendingTrip,
                                    busy: busyRequests.contains(request.id),
                                    onAccept: () =>
                                        onAccept(pendingTrip, request),
                                    onReject: () =>
                                        onReject(pendingTrip, request),
                                  ),
                                ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    RoutbCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RoutbCardHeader(
                            title: 'Mis rutas',
                            count: state.trips.length,
                          ),
                          if (!state.hasTrips)
                            const RoutbEmptyState(
                              icon: Icons.route_rounded,
                              message:
                                  'Todavía no has publicado ninguna ruta. '
                                  'Crea la primera y los pasajeros la verán al '
                                  'instante.',
                            )
                          else
                            for (final item in state.trips)
                              RoutbEntrance(
                                index: state.trips.indexOf(item),
                                child: RouteCard(
                                  trip: item,
                                  selected: item.id == state.selected?.id,
                                  highlight: item.id == highlightedTripId,
                                  onSelect: () => onSelect(item),
                                  onOpenDetail: () => onOpenDetail(item),
                                  onCancel: () => onCancel(item),
                                ),
                              ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 96),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hero del modo conductor: mapa, hora y cupos de la ruta seleccionada.
class HeroSection extends StatelessWidget {
  const HeroSection({
    required this.userName,
    required this.role,
    required this.trip,
    required this.onLogout,
    super.key,
  });

  final String userName;
  final UserRole role;
  final Trip? trip;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final selected = trip;

    return Container(
      decoration: BoxDecoration(
        gradient: palette.heroGradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(34)),
      ),
      // El padding inferior deja el hueco que ocupa el cuerpo al subir sobre el
      // hero. Las dos mitades del solapamiento salen de la misma constante para
      // que no se descuadren al tocar una.
      padding: const EdgeInsets.fromLTRB(18, 0, 18, _bodyOverlap + 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          HeroBar(
            role: role,
            userName: userName,
            onLogout: onLogout,
            isDarkBackground: true,
          ),
          const SizedBox(height: 16),
          if (selected == null)
            _EmptyHeroMessage()
          else ...[
            // El alto del mapa cede en pantallas cortas para que las
            // solicitudes y las rutas tengan más espacio visible.
            RoutbTripMap(trip: selected, height: _mapHeight(context)),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        selected.routeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RoutbText.copy(
                          12,
                          color: const Color(0xBFFFFFFF),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        selected.departureLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RoutbText.headline(
                          30,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // La columna de cupos se limita para que en pantallas
                // estrechas el texto de hora y el de cupos repartan el ancho
                // en vez de desbordar.
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      HeroSeatSlots(trip: selected),
                      const SizedBox(height: 4),
                      Text(
                        '${selected.availableSeats}/${selected.totalSeats} cupos libres',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: RoutbText.copy(
                          12,
                          color: const Color(0xBFFFFFFF),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Alto del mapa según la pantalla.
  ///
  /// El hero es un bloque grande por diseño, pero con 168 fijos se comía más de
  /// la mitad de un teléfono corto y el contenido de verdad —las solicitudes y
  /// las rutas— quedaba aplastado contra el mapa. Los tres tramos están
  /// elegidos para que el hero ocupe siempre una proporción parecida del alto.
  static double _mapHeight(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    if (height < 620) return 92;
    if (height < 780) return 120;
    return 150;
  }
}

class _EmptyHeroMessage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0x1FFFFFFF),
        borderRadius: BorderRadius.circular(RoutbTheme.radiusTile),
        border: Border.all(color: const Color(0x24FFFFFF)),
      ),
      child: Row(
        children: [
          const Icon(Icons.add_road_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Publica tu primera ruta para ver aquí el mapa, la hora de salida '
              'y los cupos.',
              style: RoutbText.copy(13, color: const Color(0xD9FFFFFF)),
            ),
          ),
        ],
      ),
    );
  }
}

/// `.fab`: botón flotante de nueva ruta.
class _NewRouteButton extends StatelessWidget {
  const _NewRouteButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Semantics(
      button: true,
      label: 'Publicar una nueva ruta',
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: palette.primaryGradient,
          borderRadius: BorderRadius.circular(RoutbTheme.radiusPill),
          boxShadow: palette.raisedShadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(RoutbTheme.radiusPill),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Nueva ruta',
                    style: RoutbText.copy(
                      14,
                      color: palette.onBrand,
                      weight: FontWeight.w700,
                    ),
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

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 24),
      children: const [
        RoutbSkeleton(height: 190, radius: 34),
        SizedBox(height: 14),
        RoutbSkeleton(height: 130),
        SizedBox(height: 14),
        RoutbSkeleton(height: 220),
      ],
    );
  }
}

class _FailedBody extends StatelessWidget {
  const _FailedBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 60, 14, 24),
      children: [
        RoutbEmptyState(
          icon: Icons.cloud_off_rounded,
          message: message,
          action: RoutbButton(
            label: 'Reintentar',
            icon: Icons.refresh_rounded,
            variant: RoutbButtonVariant.secondary,
            expand: false,
            height: 44,
            onPressed: onRetry,
          ),
        ),
      ],
    );
  }
}
