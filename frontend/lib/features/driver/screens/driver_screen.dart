import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/dependencies.dart';
import '../../../core/models/initials.dart';
import '../../../core/models/trip.dart';
import '../../../core/models/trip_request.dart';
import '../../../core/models/trip_status.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/models/user_role.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/routb_palette.dart';
import '../../../core/theme/routb_text.dart';
import '../../../core/widgets/routb_button.dart';
import '../../../core/widgets/routb_card.dart';
import '../../../core/widgets/routb_journey_board.dart';
import '../../../core/widgets/routb_history_section.dart';
import '../../../core/widgets/routb_nav_bar.dart';
import '../../../core/widgets/routb_live_pill.dart';
import '../../../core/widgets/routb_section_header.dart';
import '../../../core/widgets/routb_seats.dart';
import '../../../core/widgets/routb_toast.dart';
import '../../auth/data/auth_repository.dart';
import '../../notifications/push_notification_service.dart';
import '../../profile/screens/profile_screen.dart';
import '../../safety/models/active_trip_info.dart';
import '../../safety/screens/security_screen.dart';
import '../../trips/data/trip_repository.dart';
import '../../trips/screens/active_trip_empty_screen.dart';
import '../state/driver_state.dart';
import '../widgets/driver_cards.dart';
import '../widgets/publish_route_sheet.dart';
import '../widgets/request_preview_sheet.dart';
import '../widgets/routb_trip_map.dart';
import 'route_detail_screen.dart';

/// Pestañas del modo conductor, en el orden de la barra inferior.
enum _DriverTab { routes, history, security, profile }

/// Modo conductor: publica rutas, responde solicitudes y sigue las que tiene.
///
/// La selección vincula la tarjeta de ruta con su mapa, hora y ocupación.
class DriverScreen extends StatefulWidget {
  const DriverScreen({required this.account, super.key});

  /// Cuenta que inició sesión.
  final Account account;

  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen>
    with WidgetsBindingObserver {
  DriverState _state = const DriverState(status: DriverStatus.loading);
  _DriverTab _tab = _DriverTab.routes;
  final Set<int> _busyRequests = <int>{};
  int? _highlightedTripId;
  bool _asked = false;
  bool _appInForeground = true;
  ValueNotifier<int>? _refreshSignal;
  VoidCallback? _refreshListener;
  StreamSubscription<RoutbPushEvent>? _pushSubscription;
  PushNotificationService? _pushService;
  Timer? _highlightTimer;
  Timer? _activeTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // El estado «vigente» de una ruta depende del reloj. Un latido lento
    // mantiene el indicador del centro al día sin consultar al backend.
    _activeTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted && _appInForeground) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appInForeground = state == AppLifecycleState.resumed;
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final signal = RoutbScopeDependencies.of(context).requestRefresh;
    if (_refreshSignal != signal) {
      if (_refreshSignal != null && _refreshListener != null) {
        _refreshSignal!.removeListener(_refreshListener!);
      }
      _refreshSignal = signal;
      _refreshListener = () => unawaited(_load());
      signal.addListener(_refreshListener!);
    }
    final push = RoutbScopeDependencies.of(context).push;
    if (_pushService != push) {
      unawaited(_pushSubscription?.cancel());
      _pushService = push;
      _pushSubscription = push.events.listen(_onPushEvent);
      final pending = push.takePendingTap();
      if (pending != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _onPushEvent(pending);
        });
      }
    }
    // La primera carga se pide desde aquí y no desde `initState`: el
    // repositorio se lee del `RoutbScopeDependencies`, y buscar un inherited
    // widget antes de que `initState` termine lanza una aserción que deja la
    // pantalla sin pintar.
    if (_asked) return;
    _asked = true;
    unawaited(_load());
  }

  TripRepository get _trips => RoutbScopeDependencies.of(context).trips;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _highlightTimer?.cancel();
    _activeTimer?.cancel();
    unawaited(_pushSubscription?.cancel());
    if (_refreshSignal != null && _refreshListener != null) {
      _refreshSignal!.removeListener(_refreshListener!);
    }
    super.dispose();
  }

  /// Refresca las rutas y resalta el viaje afectado cuando llega un push.
  void _onPushEvent(RoutbPushEvent event) {
    if (!mounted || !event.hasContent) return;

    if (event.foreground) {
      RoutbToast.show(
        context,
        event.body.isNotEmpty ? event.body : event.title,
      );
    }
    if (event.tripId != null) {
      _highlightTimer?.cancel();
      setState(() => _highlightedTripId = event.tripId);
      _highlightTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _highlightedTripId = null);
      });
    }
    unawaited(_load());

    if (event.foreground) return;
    if (event.event == 'request_created') {
      _focusTab(_DriverTab.routes);
    } else if (event.event == 'trip_cancelled') {
      _focusTab(_DriverTab.history);
    }
  }

  /// Vuelve a la raíz y cambia de pestaña, para que un push no deje abierta una
  /// pantalla de detalle encima.
  void _focusTab(_DriverTab tab) {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() => _tab = tab);
  }

  /// Rutas que todavía cuentan como activas para el botón central.
  ///
  /// «Activa» es una ruta publicada que aún no terminó: programada, en curso o
  /// próxima. Una ruta de hoy que ya superó su ventana de viaje deja de
  /// encender el indicador aunque siga en «Mis rutas» hasta que cambie el día.
  List<Trip> get _activeTrips {
    final now = DateTime.now();
    return _state.trips
        .where((trip) {
          if (!trip.status.isActive) return false;
          final phase = trip.phaseAt(now);
          return phase == TripPhase.scheduled || phase == TripPhase.onCourse;
        })
        .toList(growable: false);
  }

  /// Ruta activa que debe abrir el botón central: la de salida más próxima.
  Trip? get _nearestTrip {
    final trips = _activeTrips;
    if (trips.isEmpty) return null;

    final now = DateTime.now();
    final ordered = List<Trip>.of(trips)
      ..sort((a, b) => _tripStart(a).compareTo(_tripStart(b)));
    for (final trip in ordered) {
      if (_tripStart(trip).isAfter(now)) return trip;
    }
    return ordered.first;
  }

  DateTime _tripStart(Trip trip) {
    final date = trip.departureDate ?? DateTime.now();
    final time = trip.departure;
    return DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? 23,
      time?.minute ?? 59,
    );
  }

  ActiveTripInfo? get _activeTripInfo {
    final trip = _nearestTrip;
    if (trip == null) return null;
    return ActiveTripInfo(
      origin: trip.origin,
      destination: trip.destination,
      departureLabel: trip.departureLabel,
    );
  }

  Future<void> _openActiveTrip() async {
    if (_state.status == DriverStatus.loading) await _load();
    if (!mounted) return;
    if (_state.status == DriverStatus.failed) {
      RoutbToast.show(
        context,
        'No se pudieron cargar tus rutas. Intenta de nuevo.',
      );
      return;
    }

    final trip = _nearestTrip;
    if (trip == null) {
      final shortcut = await Navigator.of(context).push<ActiveTripShortcut>(
        RoutbPageRoute<ActiveTripShortcut>(
          child: const ActiveTripEmptyScreen(role: UserRole.driver),
        ),
      );
      if (shortcut == ActiveTripShortcut.publish && mounted) {
        setState(() => _tab = _DriverTab.routes);
        await _openPublishSheet(widget.account);
      }
      return;
    }

    await _openDetail(trip);
  }

  Future<void> _load() async {
    try {
      final mine = await _trips.listMine();
      // El historial son las rutas canceladas o cuya fecha ya pasó.
      final history = await _trips.listMine(scope: 'history');
      // En «Mis rutas» solo quedan las vigentes (hoy o mañana): las que ya
      // pasaron de fecha viven en el historial.
      final now = DateTime.now();
      final current = mine
          .where((trip) => !trip.isPastDate(now))
          .toList(growable: false);
      // Los viajes vigentes ya vienen enriquecidos directamente desde listMine().
      final enriched = current;

      if (!mounted) return;
      final previous = _state.selected;
      final selected = previous == null
          ? enriched.firstOrNull
          : enriched.where((trip) => trip.id == previous.id).firstOrNull ??
                enriched.firstOrNull;
      setState(() {
        _state = DriverState(
          status: DriverStatus.ready,
          trips: enriched,
          history: history,
          selected: selected,
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
        availableSeats: (trip.availableSeats - accepted.seatCount).clamp(
          0,
          trip.totalSeats,
        ),
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
          ? (trip.availableSeats + request.seatCount).clamp(0, trip.totalSeats)
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

  void _openRequestPreview(Trip trip, TripRequest request) {
    showRequestPreviewSheet(
      context: context,
      trip: trip,
      request: request,
      onAccept: () => _accept(trip, request),
      onReject: () => _reject(trip, request),
    );
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
      final cancelled = await _trips.cancel(trip.id);
      if (!mounted) return;
      final remaining = _state.trips
          .where((item) => item.id != trip.id)
          .toList(growable: false);
      setState(() {
        _state = _state.copyWith(
          trips: remaining,
          history: <Trip>[cancelled, ..._state.history],
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

  Future<void> _openPublishSheet(Account account) async {
    final auth = RoutbScopeDependencies.of(context).auth;
    UserProfile profile;
    try {
      profile = await auth.fetchProfile();
    } on Exception catch (error, stack) {
      logFailure('la consulta del perfil antes de publicar', error, stack);
      if (!mounted) return;
      RoutbToast.show(context, describeFailure(error));
      return;
    }
    if (!mounted) return;
    if (!profile.hasCompleteVehicle) {
      await _showVehicleRequired(profile);
      return;
    }

    final draft = await showPublishRouteSheet(
      context: context,
      driverName: account.name,
      driverInitials: initialsOf(account.name),
    );
    if (draft == null || !mounted) return;

    try {
      final published = await _trips.publish(
        origin: draft.origin,
        destination: draft.destination,
        departureTime: draft.departure.label,
        departureDate: draft.departureDate,
        meetingPoint: draft.meetingPoint.trim(),
        seats: draft.seats,
        direction: draft.direction,
        driverPoint: draft.driverPoint,
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
      if (error.detail == 'vehicle_required') {
        await _showVehicleRequired();
        return;
      }
      RoutbToast.show(context, error.message);
    }
  }

  /// N2: sin modelo, color y placa el servidor no permite publicar.
  ///
  /// Se avisa antes de abrir el formulario y se lleva a Perfil, donde vive la
  /// tarjeta «Vehículo». El resto de la app sigue disponible.
  Future<void> _showVehicleRequired([UserProfile? profile]) async {
    final missing = profile?.missingVehicleFields ?? const <String>[];
    final detail = missing.isEmpty
        ? 'Registra el modelo, el color y la placa para publicar una ruta.'
        : 'Falta completar: ${missing.join(', ')}.';
    final goToProfile = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Configura tu vehículo'),
        content: Text(
          '$detail\n\nSin esos datos no puedes publicar rutas. Puedes '
          'completarlos en Perfil → Vehículo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Ahora no'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Ir a Perfil'),
          ),
        ],
      ),
    );
    if (goToProfile == true && mounted) {
      setState(() => _tab = _DriverTab.profile);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dependencies = RoutbScopeDependencies.of(context);
    return ValueListenableBuilder<String?>(
      valueListenable: dependencies.profileName,
      builder: (context, profileName, _) {
        final name = (profileName ?? widget.account.name).trim();
        return _build(
          context,
          Account(
            name: name.isEmpty ? widget.account.name : name,
            role: widget.account.role,
            token: widget.account.token,
          ),
        );
      },
    );
  }

  Widget _build(BuildContext context, Account account) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.background,
      bottomNavigationBar: RoutbNavBar(
        items: const [
          RoutbNavItem(label: 'Mis rutas', icon: Icons.route_rounded),
          RoutbNavItem(label: 'Historial', icon: Icons.history_rounded),
          RoutbNavItem(label: 'Seguridad', icon: Icons.shield_outlined),
          RoutbNavItem(label: 'Perfil', icon: Icons.person_outline_rounded),
        ],
        selectedIndex: _tab.index,
        onSelected: (index) => setState(() => _tab = _DriverTab.values[index]),
        onCenterTap: _openActiveTrip,
        centerActive: _nearestTrip != null,
      ),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: RoutbJourneyBoard.maxWidth,
                ),
                child: switch (_tab) {
                  _DriverTab.routes => _Body(
                    account: account,
                    state: _state,
                    onPublish: () => _openPublishSheet(account),
                    busyRequests: _busyRequests,
                    highlightedTripId: _highlightedTripId,
                    onSelect: (trip) => setState(
                      () => _state = _state.copyWith(selected: trip),
                    ),
                    onAccept: _accept,
                    onReject: _reject,
                    onOpenPreview: _openRequestPreview,
                    onCancel: _confirmCancel,
                    onOpenDetail: _openDetail,
                    onRefresh: _load,
                  ),
                  _DriverTab.history => _HistoryTab(
                    state: _state,
                    onRefresh: _load,
                    onOpen: _openHistoryDetail,
                  ),
                  _DriverTab.security => SecurityScreen(
                    role: UserRole.driver,
                    userName: account.name,
                    activeTrip: _activeTripInfo,
                  ),
                  _DriverTab.profile => ProfileScreen(account: account),
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

  /// Abre una ruta del historial solo para consultarla.
  Future<void> _openHistoryDetail(Trip trip) async {
    await Navigator.of(context).push(
      RoutbPageRoute<void>(
        child: RouteDetailScreen(
          trip: trip,
          readOnly: true,
          onChanged: (_) {},
          onCancelled: () {},
        ),
      ),
    );
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
    required this.onPublish,
    required this.busyRequests,
    required this.highlightedTripId,
    required this.onSelect,
    required this.onAccept,
    required this.onReject,
    required this.onOpenPreview,
    required this.onCancel,
    required this.onOpenDetail,
    required this.onRefresh,
  });

  final Account account;
  final DriverState state;
  final VoidCallback onPublish;
  final Set<int> busyRequests;
  final int? highlightedTripId;
  final ValueChanged<Trip> onSelect;
  final void Function(Trip trip, TripRequest request) onAccept;
  final void Function(Trip trip, TripRequest request) onReject;
  final void Function(Trip trip, TripRequest request) onOpenPreview;
  final ValueChanged<Trip> onCancel;
  final ValueChanged<Trip> onOpenDetail;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final selected = state.selected;
    return RoutbJourneyBoard(
      storageKey: 'driver-routes',
      onRefresh: onRefresh,
      header: Column(
        children: [
          RoutbJourneyHeader(
            title: 'Mis rutas',
            userName: account.name,
            controls: state.status != DriverStatus.ready
                ? const SizedBox.shrink()
                : JourneyAction(
                    icon: Icons.add_road_rounded,
                    label: 'Nueva ruta',
                    onTap: onPublish,
                  ),
          ),
          if (selected != null) ...[
            const SizedBox(height: 16),
            _SelectedRoute(trip: selected),
          ],
        ],
      ),
      slivers: switch (state.status) {
        DriverStatus.loading => const [JourneyFeedbackSliver.loading()],
        DriverStatus.failed => [
          JourneyFeedbackSliver.error(
            message: state.errorMessage ?? 'No se pudieron cargar tus rutas.',
            onRetry: onRefresh,
          ),
        ],
        DriverStatus.ready => [
          if (state.pendingRequestCount > 0) ...[
            SliverToBoxAdapter(
              child: JourneySectionTitle(
                'Solicitudes pendientes',
                count: state.pendingRequestCount,
              ),
            ),
            SliverList.list(
              children: [
                for (final trip in state.tripsWithPendingRequests)
                  for (final request in trip.requests.pending)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: RequestTile(
                        request: request,
                        trip: trip,
                        busy: busyRequests.contains(request.id),
                        onTapPreview: () => onOpenPreview(trip, request),
                        onAccept: () => onAccept(trip, request),
                        onReject: () => onReject(trip, request),
                      ),
                    ),
              ],
            ),
          ],
          SliverToBoxAdapter(
            child: JourneySectionTitle(
              'Rutas publicadas',
              count: state.trips.length,
            ),
          ),
          if (!state.hasTrips)
            SliverToBoxAdapter(
              child: RoutbCard(
                child: RoutbEmptyState(
                  icon: Icons.add_road_rounded,
                  message: state.hasHistory
                      ? 'No tienes rutas vigentes. Puedes consultar las anteriores en Historial.'
                      : 'Publica tu primera ruta para que otros estudiantes puedan solicitar un cupo.',
                ),
              ),
            )
          else
            SliverList.builder(
              itemCount: state.trips.length,
              itemBuilder: (context, index) {
                final trip = state.trips[index];
                return RouteCard(
                  key: ValueKey(trip.id),
                  trip: trip,
                  selected: trip.id == selected?.id,
                  highlight: trip.id == highlightedTripId,
                  onSelect: () => onSelect(trip),
                  onOpenDetail: () => onOpenDetail(trip),
                  onCancel: () => onCancel(trip),
                );
              },
            ),
        ],
      },
    );
  }
}

class _SelectedRoute extends StatelessWidget {
  const _SelectedRoute({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return RoutbCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                'Ruta seleccionada',
                style: RoutbText.copy(12, color: p.muted),
              ),
              LivePill(phase: trip.phaseAt(DateTime.now()), onDark: false),
            ],
          ),
          const SizedBox(height: 3),
          Text(trip.routeLabel, style: RoutbText.headline(21, color: p.ink)),
          const SizedBox(height: 12),
          RoutbTripMap(
            trip: trip,
            height: MediaQuery.sizeOf(context).height < 680 ? 108 : 148,
            showPhase: false,
            animateRoute: !MediaQuery.disableAnimationsOf(context),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.departureDateLabel,
                      style: RoutbText.copy(12, color: p.muted),
                    ),
                    Text(
                      trip.departureLabel,
                      style: RoutbText.headline(23, color: p.ink),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    HeroSeatSlots(trip: trip),
                    const SizedBox(height: 3),
                    Text(
                      '${trip.availableSeats}/${trip.totalSeats} cupos libres',
                      style: RoutbText.copy(12, color: p.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Pestaña de historial: rutas canceladas o ya pasadas, solo para consultar.
///
/// Sigue el mismo esquema que «Mis viajes» del pasajero: un hero con la cuenta
/// y debajo la lista. Las rutas vigentes siguen en «Mis rutas».
class _HistoryTab extends StatelessWidget {
  const _HistoryTab({
    required this.state,
    required this.onRefresh,
    required this.onOpen,
  });

  final DriverState state;
  final Future<void> Function() onRefresh;
  final ValueChanged<Trip> onOpen;

  @override
  Widget build(BuildContext context) {
    return RoutbSectionPage(
      title: 'Historial',
      subtitle: 'Rutas completadas y canceladas',
      icon: Icons.history_rounded,
      body: (_) => switch (state.status) {
        DriverStatus.loading => const _LoadingBody(),
        DriverStatus.failed => _FailedBody(
          message: state.errorMessage ?? 'Algo salió mal.',
          onRetry: onRefresh,
        ),
        DriverStatus.ready => _HistoryList(
          trips: state.history,
          onRefresh: onRefresh,
          onOpen: onOpen,
        ),
      },
    );
  }
}

/// Lista del historial, o su estado vacío, con «deslizar para actualizar».
class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.trips,
    required this.onRefresh,
    required this.onOpen,
  });

  final List<Trip> trips;
  final Future<void> Function() onRefresh;
  final ValueChanged<Trip> onOpen;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final now = DateTime.now();
    final completed = <Trip>[];
    final cancelled = <Trip>[];
    for (final trip in trips) {
      if (trip.phaseAt(now) == TripPhase.cancelled) {
        cancelled.add(trip);
      } else {
        completed.add(trip);
      }
    }

    Widget tile(Trip trip) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: HistoryRouteTile(trip: trip, onTap: () => onOpen(trip)),
    );

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: trips.isEmpty
          ? ListView(
              key: const PageStorageKey<String>('driver-history-empty'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: const [
                SizedBox(height: 12),
                RoutbEmptyState(
                  icon: Icons.history_rounded,
                  message:
                      'Todavía no tienes rutas completadas ni canceladas. '
                      'Las vigentes siguen en «Mis rutas».',
                ),
              ],
            )
          : ListView(
              key: const PageStorageKey<String>('driver-history'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
              children: [
                if (completed.isNotEmpty)
                  RoutbHistorySection(
                    title: 'Completadas',
                    icon: Icons.check_circle_outline_rounded,
                    color: palette.mint,
                    count: completed.length,
                    children: [for (final trip in completed) tile(trip)],
                  ),
                if (cancelled.isNotEmpty)
                  RoutbHistorySection(
                    title: 'Canceladas',
                    icon: Icons.cancel_outlined,
                    color: palette.rose,
                    count: cancelled.length,
                    children: [for (final trip in cancelled) tile(trip)],
                  ),
              ],
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
