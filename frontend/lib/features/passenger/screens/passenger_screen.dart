import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/dependencies.dart';
import '../../../core/models/my_request.dart';
import '../../../core/models/trip.dart';
import '../../../core/models/trip_filters.dart';
import '../../../core/models/trip_schedule.dart';
import '../../../core/models/user_role.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/routb_palette.dart';
import '../../../core/theme/routb_text.dart';
import '../../../core/theme/routb_theme.dart';
import '../../../core/widgets/date_quick_picker.dart';
import '../../../core/widgets/route_map.dart';
import '../../../core/widgets/routb_anim.dart';
import '../../../core/widgets/routb_button.dart';
import '../../../core/widgets/routb_hero.dart';
import '../../../core/widgets/routb_nav_bar.dart';
import '../../../core/widgets/routb_section_header.dart';
import '../../../core/widgets/routb_seats.dart';
import '../../../core/widgets/routb_sheet.dart';
import '../../../core/widgets/routb_toast.dart';
import '../../auth/data/auth_repository.dart';
import '../../notifications/push_notification_service.dart';
import '../../profile/screens/profile_screen.dart';
import '../../safety/models/active_trip_info.dart';
import '../../safety/screens/security_screen.dart';
import '../../trips/data/trip_repository.dart';
import '../../trips/screens/active_trip_empty_screen.dart';
import '../../matching/presentation/suggestions_screen.dart';
import '../widgets/my_trip_card.dart';
import '../widgets/reserve_seats_sheet.dart';
import '../widgets/trip_card.dart';
import 'active_trips_screen.dart';
import 'my_trip_screen.dart';

/// Estado de la lista de viajes del pasajero.
enum PassengerStatus { loading, ready, failed }

enum _PassengerTab { search, history, security, profile }

/// Modo pasajero: busca viajes, compara horarios y solicita cupos.
///
/// El buscador filtra en el servidor con `origin` y `destination`, que es donde
/// el backend hace la comparación. Cada tecla espera un momento antes de
/// consultar para no lanzar una petición por pulsación.
class PassengerScreen extends StatefulWidget {
  const PassengerScreen({required this.account, super.key});

  /// Cuenta que inició sesión.
  final Account account;

  @override
  State<PassengerScreen> createState() => _PassengerScreenState();
}

class _PassengerScreenState extends State<PassengerScreen>
    with WidgetsBindingObserver {
  /// Cadencia del sondeo de rescate: ni tan corta que gaste batería ni tan
  /// larga que el pasajero se quede esperando una respuesta que ya llegó.
  static const Duration _pollInterval = Duration(seconds: 15);

  final TextEditingController _origin = TextEditingController();
  final TextEditingController _destination = TextEditingController();

  PassengerStatus _status = PassengerStatus.loading;
  List<Trip> _trips = const <Trip>[];
  List<MyRequest> _myRequests = const <MyRequest>[];
  String _errorMessage = '';
  Timer? _debounce;
  Timer? _pollTimer;
  Timer? _clockTimer;
  bool _filtering = false;
  bool _appInForeground = true;
  bool _myRequestsInFlight = false;
  DateTime _selectedDate = TripSchedule.dateOnly(DateTime.now());
  _PassengerTab _selectedTab = _PassengerTab.search;
  bool _myRequestsLoading = true;
  bool _myRequestsFailed = false;
  int? _busyTripId;
  int? _busyRequestId;
  bool _asked = false;
  ValueNotifier<int>? _refreshSignal;
  VoidCallback? _refreshListener;
  StreamSubscription<RoutbPushEvent>? _pushSubscription;
  PushNotificationService? _pushService;
  DateTime? _lastMyRequestsSync;
  DateTime? _lastPushAt;
  String? _lastPushKey;
  TripTimeRange _timeRange = TripTimeRange.any;
  TripSortOrder _sortOrder = TripSortOrder.earliest;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      _refreshListener = () {
        unawaited(_loadMyRequests());
        unawaited(_load());
      };
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _clockTimer?.cancel();
    unawaited(_pushSubscription?.cancel());
    if (_refreshSignal != null && _refreshListener != null) {
      _refreshSignal!.removeListener(_refreshListener!);
    }
    _debounce?.cancel();
    _origin.dispose();
    _destination.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _appInForeground) return;
    _appInForeground = foreground;
    // Al volver se reanuda solo si sigue habiendo una solicitud pendiente; en
    // segundo plano se apaga para no drenar la batería.
    _evaluatePolling();
    _evaluateClock();
  }

  TripRepository get _repository => RoutbScopeDependencies.of(context).trips;

  Future<void> _load() async {
    if (_status != PassengerStatus.ready) {
      setState(() {
        _status = PassengerStatus.loading;
        _errorMessage = '';
      });
    }

    try {
      final trips = await _repository.listAvailable(
        origin: _origin.text,
        destination: _destination.text,
        departureDate: _selectedDate,
      );
      if (!mounted) return;
      setState(() {
        _trips = trips;
        _status = PassengerStatus.ready;
        _filtering = false;
      });
      // Las solicitudes propias van aparte: si fallan, el buscador sigue
      // funcionando y solo se pierde la lista de «Mis viajes».
      await _loadMyRequests();
    } on Exception catch (error, stack) {
      logFailure('la carga de viajes', error, stack);
      if (!mounted) return;
      setState(() {
        _status = PassengerStatus.failed;
        _errorMessage = describeFailure(error);
        _filtering = false;
      });
    }
  }

  Future<void> _loadMyRequests({bool silent = false}) async {
    // Una consulta anterior puede seguir en curso: el sondeo se salta el turno
    // en vez de encadenar peticiones sobre redes lentas.
    if (_myRequestsInFlight) return;
    _myRequestsInFlight = true;
    if (mounted && !silent) {
      setState(() {
        _myRequestsLoading = true;
        _myRequestsFailed = false;
      });
    }
    try {
      final requests = await _repository.myRequests();
      if (!mounted) return;
      setState(() {
        _myRequests = requests;
        _myRequestsLoading = false;
        _myRequestsFailed = false;
        _lastMyRequestsSync = DateTime.now();
      });
      _evaluatePolling();
      _evaluateClock();
    } on Exception catch (error, stack) {
      logFailure('la carga de mis solicitudes', error, stack);
      if (!mounted) return;
      // Un fallo del sondeo no debe borrar la lista que el pasajero ya veía:
      // se reintenta en el siguiente turno.
      if (!silent) {
        setState(() {
          _myRequestsLoading = false;
          _myRequestsFailed = true;
        });
      }
    } finally {
      _myRequestsInFlight = false;
    }
  }

  /// Mantiene el autorefresco solo mientras haya solicitudes en espera.
  ///
  /// Es la red de rescate cuando FCM no llega (permisos denegados, app en
  /// segundo plano restrictivo o red inestable). Se apaga en cuanto la última
  /// solicitud deja de estar pendiente o la app pasa a segundo plano.
  void _evaluatePolling() {
    final hasPending = _myRequests.any(
      (request) => request.isPending && request.isActive,
    );
    if (!hasPending || !_appInForeground) {
      _pollTimer?.cancel();
      _pollTimer = null;
      return;
    }
    _pollTimer ??= Timer.periodic(_pollInterval, (_) {
      if (_myRequestsInFlight) return;
      unawaited(_loadMyRequests(silent: true));
    });
  }

  /// Refresca solo el reloj mientras haya un cupo confirmado.
  ///
  /// Así el indicador del botón central se apaga cuando el viaje termina sin
  /// encadenar consultas al backend; el sondeo de red sigue reservado para las
  /// solicitudes pendientes.
  void _evaluateClock() {
    final hasConfirmed = _myRequests.any(
      (request) => request.isActive && request.isConfirmed,
    );
    if (!hasConfirmed || !_appInForeground) {
      _clockTimer?.cancel();
      _clockTimer = null;
      return;
    }
    _clockTimer ??= Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  /// Viajes que se pintan: sin los que ya tienen un cupo confirmado, sin los
  /// que ya salieron y con los filtros de hora y orden elegidos por el pasajero.
  List<Trip> get _visibleTrips {
    final now = DateTime.now();
    final confirmedTripIds = _myRequests
        .where((request) => request.isActive && request.isConfirmed)
        .map((request) => request.tripId)
        .toSet();
    final available = confirmedTripIds.isEmpty
        ? _trips
        : _trips
              .where((trip) => !confirmedTripIds.contains(trip.id))
              .toList(growable: false);
    final upcoming = available
        .where((trip) => !trip.hasDeparted(now))
        .toList(growable: false);
    return filterAndSortTrips(upcoming, range: _timeRange, order: _sortOrder);
  }

  /// Reacciona a un push con la app abierta.
  ///
  /// Refresca solicitudes y viajes, y muestra el contenido del aviso una sola
  /// vez. El sondeo no muestra toasts, así que ambos caminos no se duplican.
  void _onPushEvent(RoutbPushEvent event) {
    if (!mounted || !event.hasContent) return;

    final key = '${event.event}:${event.tripId}:${event.title}:${event.body}';
    final now = DateTime.now();
    final repeated =
        key == _lastPushKey &&
        _lastPushAt != null &&
        now.difference(_lastPushAt!) < const Duration(seconds: 3);
    if (repeated) return;

    _lastPushKey = key;
    _lastPushAt = now;

    if (event.foreground) {
      RoutbToast.show(
        context,
        event.body.isNotEmpty ? event.body : event.title,
      );
    }
    unawaited(_loadMyRequests());
    unawaited(_load());

    if (event.foreground) return;
    switch (event.event) {
      case 'request_accepted':
        unawaited(_openActiveTripFromPush(event.tripId));
      case 'request_rejected':
      case 'trip_cancelled':
        _focusTab(_PassengerTab.history);
    }
  }

  /// Vuelve a la raíz y cambia de pestaña, para que un push no deje abierta una
  /// pantalla de detalle encima.
  void _focusTab(_PassengerTab tab) {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() => _selectedTab = tab);
  }

  /// Cancela una solicitud pendiente desde la tarjeta resumida (G5).
  Future<void> _cancelRequest(MyRequest request) async {
    if (_busyRequestId != null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final palette = dialogContext.palette;
        return AlertDialog(
          title: const Text('¿Cancelar tu solicitud?'),
          content: Text(
            'Tu solicitud a ${request.driverName ?? 'el conductor'} se '
            'descartará y podrás volver a pedir cupo en otro viaje.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Mantener solicitud'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                'Cancelar solicitud',
                style: TextStyle(color: palette.rose),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busyRequestId = request.id);
    try {
      await _repository.withdrawRequest(request.id);
      if (!mounted) return;
      await _loadMyRequests();
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      RoutbToast.show(context, 'Solicitud cancelada');
    } on ApiException catch (error) {
      if (!mounted) return;
      RoutbToast.show(context, error.message);
    } finally {
      if (mounted) setState(() => _busyRequestId = null);
    }
  }

  /// Solicitudes vivas, con las confirmadas primero y luego las pendientes.
  List<MyRequest> get _activeRequests {
    final active = _myRequests
        .where((request) => request.isActive)
        .toList(growable: false);
    if (active.length < 2) return active;
    return List<MyRequest>.of(active)..sort((a, b) {
      if (a.isConfirmed == b.isConfirmed) return 0;
      return a.isConfirmed ? -1 : 1;
    });
  }

  MyRequest? get _currentRequest {
    final active = _activeRequests;
    return active.isEmpty ? null : active.first;
  }

  /// Datos del viaje activo que usa la pestaña Seguridad en el mensaje de
  /// emergencia.
  ActiveTripInfo? get _activeTripInfo {
    final request = _currentRequest;
    if (request == null) return null;
    return ActiveTripInfo(
      origin: request.origin,
      destination: request.destination,
      departureLabel: request.departureLabel,
    );
  }

  List<MyRequest> get _completedRequests {
    final requests = _myRequests
        .where((request) => request.isCompleted)
        .toList(growable: false);
    return List<MyRequest>.of(requests)..sort((a, b) {
      final left = a.departureDate ?? a.createdAt;
      final right = b.departureDate ?? b.createdAt;
      return right.compareTo(left);
    });
  }

  List<MyRequest> get _cancelledHistoryRequests {
    final requests = _myRequests
        .where((request) => request.isHistoryCancelled)
        .toList(growable: false);
    return List<MyRequest>.of(requests)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> _openMyTrip(MyRequest request) async {
    await Navigator.of(context).push(
      RoutbPageRoute<void>(
        child: MyTripScreen(
          request: request,
          onWithdrawn: () {
            unawaited(_loadMyRequests());
            unawaited(_load());
          },
        ),
      ),
    );
    if (mounted) await _loadMyRequests();
  }

  /// Espera a que termine la carga inicial de solicitudes, si sigue en curso.
  ///
  /// El botón central está disponible desde el primer cuadro; si se pulsa antes
  /// de que llegue `/requests/me`, no debe mostrar el estado vacío por error.
  Future<void> _waitForRequests() async {
    for (var attempt = 0; attempt < 20; attempt++) {
      if (!_myRequestsLoading && !_myRequestsInFlight) return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
    }
  }

  /// Abre el viaje activo desde el botón central.
  Future<void> _openActiveTrip() async {
    await _waitForRequests();
    if (!mounted) return;

    if (_myRequestsFailed && _activeRequests.isEmpty) {
      RoutbToast.show(
        context,
        'No se pudieron cargar tus viajes. Intenta de nuevo.',
      );
      return;
    }

    final active = _activeRequests;
    if (active.isEmpty) {
      final shortcut = await Navigator.of(context).push<ActiveTripShortcut>(
        RoutbPageRoute<ActiveTripShortcut>(
          child: const ActiveTripEmptyScreen(role: UserRole.passenger),
        ),
      );
      if (shortcut == ActiveTripShortcut.search && mounted) {
        setState(() => _selectedTab = _PassengerTab.search);
      }
      return;
    }

    if (active.length == 1) {
      await _openMyTrip(active.first);
      return;
    }

    await Navigator.of(context).push(
      RoutbPageRoute<void>(
        child: ActiveTripsScreen(
          requests: active,
          lastUpdated: _lastMyRequestsSync,
          onOpen: _openMyTrip,
        ),
      ),
    );
  }

  /// Un push de «solicitud aceptada» debe abrir el detalle, no solo refrescar.
  ///
  /// El backend puede tardar un instante en dejar visible la solicitud cuando
  /// llega el aviso, así que se reintenta una vez antes de rendirse.
  Future<void> _openActiveTripFromPush(int? tripId) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      await _loadMyRequests(silent: attempt > 0);
      if (!mounted) return;
      MyRequest? match;
      for (final request in _activeRequests) {
        if (tripId == null || request.tripId == tripId) {
          match = request;
          break;
        }
      }
      if (match == null && tripId != null) {
        for (final request in _activeRequests) {
          match ??= request;
        }
      }
      if (match != null) {
        final navigator = Navigator.of(context);
        navigator.popUntil((route) => route.isFirst);
        await _openMyTrip(match);
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
    }
  }

  void _openFullMap() {
    final active = _currentRequest;
    if (active == null) return;
    RoutbSheet.show<void>(
      context: context,
      title: 'Trayecto estimado',
      subtitle:
          'El mapa sitúa origen, destino y paradas con las coordenadas reales',
      heightFactor: 0.8,
      body: RouteMap(
        origin: active.origin,
        destination: active.destination,
        waypoints: active.waypoints,
        routePoints: active.routePoints,
        // En la hoja el mapa sí se puede mover: hay sitio de sobra y no compite
        // con el scroll del resto del cuerpo.
        interactive: true,
        height: MediaQuery.sizeOf(context).height * 0.45,
      ),
    );
  }

  Future<void> _setDate(DateTime date) async {
    final selected = TripSchedule.clampToTripWindow(date);
    if (selected == _selectedDate) return;
    setState(() {
      _selectedDate = selected;
      _filtering = true;
    });
    await _load();
  }

  void _setTimeRange(TripTimeRange range) {
    if (range == _timeRange) return;
    setState(() => _timeRange = range);
  }

  void _setSortOrder(TripSortOrder order) {
    if (order == _sortOrder) return;
    setState(() => _sortOrder = order);
  }

  void _clearTimeFilter() {
    if (_timeRange == TripTimeRange.any) return;
    setState(() => _timeRange = TripTimeRange.any);
  }

  /// Alterna entre hoy y mañana desde el estado vacío, para que la sugerencia
  /// «prueba otro día» sea accionable sin abrir otro selector.
  Future<void> _showOtherDay() async {
    final today = TripSchedule.dateOnly(DateTime.now());
    final target = _selectedDate == today
        ? today.add(const Duration(days: 1))
        : today;
    await _setDate(target);
  }

  Future<void> _selectTab(_PassengerTab tab) async {
    setState(() => _selectedTab = tab);
    if (tab == _PassengerTab.history) {
      await _loadMyRequests();
    }
  }

  Future<void> _clearFilters() async {
    _debounce?.cancel();
    _origin.clear();
    _destination.clear();
    setState(() {
      _selectedDate = TripSchedule.dateOnly(DateTime.now());
      _timeRange = TripTimeRange.any;
      _sortOrder = TripSortOrder.earliest;
      _filtering = true;
    });
    await _load();
  }

  /// Abre la mini pantalla de solicitud y envía lo que se pidió en ella.
  ///
  /// Antes los viajes con `direction` se desviaban a [SuggestionsScreen], que
  /// empieza una búsqueda nueva y descarta el viaje ya elegido: se perdía el
  /// cupo que se estaba pidiendo. La parada que exige el backend para esos
  /// viajes se pide ahora dentro de la propia mini pantalla.
  Future<void> _reserve(Trip trip) async {
    if (_busyTripId != null) return;
    final choice = await showReserveSeatsSheet(context: context, trip: trip);
    if (choice == null || !mounted) return;
    setState(() => _busyTripId = trip.id);

    try {
      final request =
          choice.request ??
          await _repository.requestSeat(
            trip.id,
            seatCount: choice.seatCount,
            stops: choice.stops,
          );
      if (!mounted) return;
      // El backend descuenta los cupos al aceptar el conductor, no al solicitar,
      // así que aquí solo se marca la solicitud en curso.
      _replaceTrip(trip.copyWith(myRequestStatus: request.status));
      // Y con ella aparece la solicitud en «Mis viajes» sin esperar al
      // siguiente refresco.
      await _loadMyRequests();
      if (!mounted) return;
      final seats = choice.seatCount;
      RoutbToast.show(
        context,
        'Solicitud de $seats ${seats == 1 ? 'cupo' : 'cupos'} enviada a ${trip.hasDriverName ? trip.driverName!.split(' ').first : 'el conductor'}',
      );

      // B-2: La pantalla de búsqueda se convierte en seguimiento de ruta al solicitar/confirmar el viaje.
      // Al finalizar o cancelarse regresa limpiamente al buscador.
      final activeReq =
          _myRequests.cast<MyRequest?>().firstWhere(
            (r) => r != null && (r.tripId == trip.id || r.id == request.id),
            orElse: () => null,
          ) ??
          MyRequest(
            id: request.id,
            tripId: trip.id,
            seatCount: choice.seatCount,
            status: request.status,
            origin: trip.origin,
            destination: trip.destination,
            rawDeparture: trip.rawDeparture,
            departure: trip.departure,
            departureDate: trip.departureDate,
            meetingPoint: trip.meetingPoint,
            totalSeats: trip.totalSeats,
            availableSeats: trip.availableSeats,
            tripStatus: trip.status,
            createdAt: request.createdAt,
            driverName: trip.driverName,
            driverPhone: null,
            routePoints: trip.routePoints,
          );

      await _openMyTrip(activeReq);
    } on ApiException catch (error) {
      if (!mounted) return;
      RoutbToast.show(context, error.message);
      // El servidor es la fuente de verdad sobre el estado de la solicitud.
      await _load();
    } finally {
      if (mounted) setState(() => _busyTripId = null);
    }
  }

  void _replaceTrip(Trip updated) {
    setState(() {
      _trips = _trips
          .map((trip) => trip.id == updated.id ? updated : trip)
          .toList(growable: false);
    });
  }

  Future<void> _openSuggestions() =>
      Navigator.of(context)
          .push(RoutbPageRoute<void>(child: const SuggestionsScreen()));

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
    final trips = _visibleTrips;
    final pollingActive = _pollTimer != null && _appInForeground;
    final lastUpdated = pollingActive ? _lastMyRequestsSync : null;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: RoutbTheme.contentMaxWidth,
            ),
            child: switch (_selectedTab) {
              _PassengerTab.search => Column(
                children: [
                  _PassengerHero(
                    userName: account.name,
                    selectedDate: _selectedDate,
                    currentRequest: _currentRequest,
                    timeRange: _timeRange,
                    onDateChanged: _setDate,
                    onTimeRangeChanged: _setTimeRange,
                    onOpenMap: _openFullMap,
                    onOpenSuggestions: _openSuggestions,
                  ),
                  Expanded(
                    child: switch (_status) {
                      PassengerStatus.loading => const _TripsLoading(),
                      PassengerStatus.failed => _TripsFailed(
                        message: _errorMessage,
                        onRetry: _load,
                      ),
                      PassengerStatus.ready => _TripsList(
                        trips: trips,
                        myRequest: _currentRequest,
                        busyTripId: _busyTripId,
                        filtering: _filtering,
                        origin: _origin.text.trim(),
                        destination: _destination.text.trim(),
                        selectedDate: _selectedDate,
                        timeRange: _timeRange,
                        sortOrder: _sortOrder,
                        lastUpdated: lastUpdated,
                        busyRequestId: _busyRequestId,
                        onReserve: _reserve,
                        onOpenMyTrip: _openMyTrip,
                        onCancelRequest: _cancelRequest,
                        onSortChanged: _setSortOrder,
                        onClearTimeFilter: _clearTimeFilter,
                        onShowOtherDay: _showOtherDay,
                        onRefresh: _load,
                        onClearFilters: _clearFilters,
                      ),
                    },
                  ),
                ],
              ),
              _PassengerTab.history => _HistoryTab(
                completed: _completedRequests,
                cancelled: _cancelledHistoryRequests,
                loading: _myRequestsLoading,
                failed: _myRequestsFailed,
                onOpen: _openMyTrip,
                onRefresh: _loadMyRequests,
                onRetry: _loadMyRequests,
              ),
              _PassengerTab.security => SecurityScreen(
                role: UserRole.passenger,
                userName: account.name,
                activeTrip: _activeTripInfo,
              ),
              _PassengerTab.profile => ProfileScreen(account: account),
            },
          ),
        ),
      ),
      bottomNavigationBar: RoutbNavBar(
        items: const [
          RoutbNavItem(label: 'Viajes', icon: Icons.search_rounded),
          RoutbNavItem(label: 'Historial', icon: Icons.history_rounded),
          RoutbNavItem(label: 'Seguridad', icon: Icons.shield_outlined),
          RoutbNavItem(label: 'Perfil', icon: Icons.person_outline_rounded),
        ],
        selectedIndex: _selectedTab.index,
        onSelected: (index) => _selectTab(_PassengerTab.values[index]),
        onCenterTap: _openActiveTrip,
        centerActive: _activeRequests.isNotEmpty,
      ),
    );
  }
}

/// Hero del modo pasajero: saludo, mapa (si hay viaje activo) y acceso a búsqueda.
class _PassengerHero extends StatelessWidget {
  const _PassengerHero({
    required this.userName,
    required this.selectedDate,
    required this.timeRange,
    required this.onDateChanged,
    required this.onTimeRangeChanged,
    required this.onOpenMap,
    required this.onOpenSuggestions,
    this.currentRequest,
  });

  final String userName;
  final DateTime selectedDate;
  final TripTimeRange timeRange;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<TripTimeRange> onTimeRangeChanged;
  final VoidCallback onOpenMap;
  final VoidCallback onOpenSuggestions;
  final MyRequest? currentRequest;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final active = currentRequest;

    return Container(
      decoration: BoxDecoration(
        gradient: palette.heroGradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(34)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HeroBar(userName: userName, wave: true),
          if (active != null) ...[
            const SizedBox(height: 16),
            Stack(
              children: [
                RouteMap(
                  origin: active.origin,
                  destination: active.destination,
                  waypoints: active.waypoints,
                  routePoints: active.routePoints,
                  height: 110,
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: Material(
                    color: palette.card,
                    borderRadius: BorderRadius.circular(RoutbTheme.radiusPill),
                    child: InkWell(
                      onTap: onOpenMap,
                      borderRadius: BorderRadius.circular(
                        RoutbTheme.radiusPill,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(9, 5, 11, 5),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.fullscreen_rounded,
                              size: 13,
                              color: palette.ink,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Abrir mapa',
                              style: RoutbText.copy(
                                11,
                                color: palette.ink,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ] else ...[
            const SizedBox(height: 16),
          ],
          Container(
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: palette.line.withValues(alpha: 0.7)),
              boxShadow: palette.searchShadow,
            ),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    DateQuickPicker(
                      value: selectedDate,
                      onChanged: onDateChanged,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _TimeRangeMenu(
                          value: timeRange,
                          onChanged: onTimeRangeChanged,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Material(
                  color: palette.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: palette.brand.withValues(alpha: 0.25),
                    ),
                  ),
                  child: InkWell(
                    onTap: onOpenSuggestions,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              gradient: palette.primaryGradient,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.search_rounded,
                              size: 17,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '¿A dónde vas? Buscar ruta y paradas',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: RoutbText.copy(
                                13,
                                color: palette.ink,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: palette.brandSurface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.tune_rounded,
                              size: 14,
                              color: palette.brand,
                            ),
                          ),
                        ],
                      ),
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

/// `.lh`: encabezado con el número de viajes encontrados.
class _TripsList extends StatelessWidget {
  const _TripsList({
    required this.trips,
    required this.myRequest,
    required this.busyTripId,
    required this.filtering,
    required this.origin,
    required this.destination,
    required this.selectedDate,
    required this.timeRange,
    required this.sortOrder,
    required this.lastUpdated,
    required this.busyRequestId,
    required this.onReserve,
    required this.onOpenMyTrip,
    required this.onCancelRequest,
    required this.onSortChanged,
    required this.onClearTimeFilter,
    required this.onShowOtherDay,
    required this.onRefresh,
    required this.onClearFilters,
  });

  final List<Trip> trips;
  final MyRequest? myRequest;
  final int? busyTripId;
  final bool filtering;
  final String origin;
  final String destination;
  final DateTime selectedDate;
  final TripTimeRange timeRange;
  final TripSortOrder sortOrder;
  final DateTime? lastUpdated;
  final int? busyRequestId;
  final ValueChanged<Trip> onReserve;
  final ValueChanged<MyRequest> onOpenMyTrip;
  final ValueChanged<MyRequest> onCancelRequest;
  final ValueChanged<TripSortOrder> onSortChanged;
  final VoidCallback onClearTimeFilter;
  final Future<void> Function() onShowOtherDay;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onClearFilters;

  /// Estado vacío con una salida concreta según el filtro que esté activo.
  Widget _emptyState() {
    final dateLabel = TripSchedule.dateLabel(selectedDate);
    final today = TripSchedule.dateOnly(DateTime.now());
    final otherDayLabel = selectedDate == today ? 'Ver mañana' : 'Ver hoy';
    final hasSearch = origin.isNotEmpty || destination.isNotEmpty;

    if (timeRange != TripTimeRange.any) {
      return RoutbEmptyState(
        icon: Icons.schedule_rounded,
        message:
            'No hay viajes en la franja ${timeRange.label.toLowerCase()} '
            'para $dateLabel. Prueba con otra hora o cambia el destino.',
        action: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RoutbButton(
              label: 'Ver todas las horas',
              icon: Icons.schedule_rounded,
              variant: RoutbButtonVariant.secondary,
              expand: false,
              height: 44,
              onPressed: onClearTimeFilter,
            ),
            const SizedBox(height: 8),
            RoutbButton(
              label: otherDayLabel,
              variant: RoutbButtonVariant.secondary,
              expand: false,
              height: 44,
              onPressed: onShowOtherDay,
            ),
          ],
        ),
      );
    }

    return RoutbEmptyState(
      icon: Icons.search_off_rounded,
      message: hasSearch
          ? 'No hay viajes con esa búsqueda para $dateLabel. Prueba con otro '
                'origen, destino u hora.'
          : 'No hay viajes para $dateLabel. Prueba con otro día u otra hora.',
      action: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RoutbButton(
            label: otherDayLabel,
            variant: RoutbButtonVariant.secondary,
            expand: false,
            height: 44,
            onPressed: onShowOtherDay,
          ),
          if (hasSearch) ...[
            const SizedBox(height: 8),
            RoutbButton(
              label: 'Limpiar búsqueda',
              variant: RoutbButtonVariant.secondary,
              expand: false,
              height: 44,
              onPressed: onClearFilters,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final now = DateTime.now();
    // Con tarjeta activa el contenido supera la ventana: el estado vacío va
    // en un sliver con caja (desplazable) en vez de rellenar el resto, que lo
    // dejaría sin espacio y sin construir.
    final emptyState = _emptyState();

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        key: const PageStorageKey<String>('passenger-search-results'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // La tarjeta va antes que el encabezado, incluso con cero
          // resultados: el viaje confirmado desaparece del listado cuando se
          // llena, que es justo cuando el pasajero necesita verlo.
          if (myRequest != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                child: MyTripCard(
                  request: myRequest!,
                  onTap: () => onOpenMyTrip(myRequest!),
                  onCancel: () => onCancelRequest(myRequest!),
                  busy: busyRequestId == myRequest!.id,
                  lastUpdated: lastUpdated,
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
              child: Row(
                children: [
                  // El título cede espacio antes que el contador: en pantallas
                  // estrechas es lo que evita que la fila se desborde. No lleva
                  // `Spacer` detrás porque el separador se lo comería entero y el
                  // título saldría cortado sin necesidad.
                  Flexible(
                    child: Text(
                      'Viajes disponibles',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RoutbText.headline(18, color: palette.ink),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: palette.ink,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '${trips.length}',
                      style: RoutbText.copy(
                        12,
                        color: palette.background,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _SortMenu(value: sortOrder, onChanged: onSortChanged),
                  // El separador solo aparece mientras se busca, y es el que
                  // empuja el indicador al borde derecho.
                  if (filtering)
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: palette.brand,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (trips.isEmpty)
            if (myRequest != null)
              SliverToBoxAdapter(child: emptyState)
            else
              SliverFillRemaining(hasScrollBody: false, child: emptyState)
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
              sliver: SliverList.builder(
                itemCount: trips.length,
                itemBuilder: (context, index) {
                  final trip = trips[index];
                  final state = trip.bookingStateAt(now);
                  return RoutbEntrance(
                    index: index,
                    child: TripCard(
                      trip: trip,
                      index: index,
                      now: now,
                      isNew: trip.isImminent(now),
                      onReserve: state.isActionable && busyTripId == null
                          ? () => onReserve(trip)
                          : null,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Selector compacto de la franja horaria del hero.
class _TimeRangeMenu extends StatelessWidget {
  const _TimeRangeMenu({required this.value, required this.onChanged});

  final TripTimeRange value;
  final ValueChanged<TripTimeRange> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return PopupMenuButton<TripTimeRange>(
      tooltip: 'Filtrar por hora: ${value.label}',
      initialValue: value,
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      itemBuilder: (context) => [
        for (final range in TripTimeRange.values)
          PopupMenuItem<TripTimeRange>(
            value: range,
            child: Row(
              children: [
                Icon(
                  range == value
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 18,
                  color: range == value ? palette.brand : palette.muted,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(range.label)),
              ],
            ),
          ),
      ],
      child: Container(
        height: 32,
        padding: const EdgeInsets.only(left: 9, right: 3),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(RoutbTheme.radiusPill),
          border: Border.all(color: palette.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Flexible(
              child: Text(
                value.shortLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: RoutbText.copy(
                  11.5,
                  color: palette.ink,
                  weight: FontWeight.w700,
                ),
              ),
            ),
            Icon(Icons.arrow_drop_down_rounded, size: 16, color: palette.muted),
          ],
        ),
      ),
    );
  }
}

/// Selector compacto del orden de los resultados.
class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.value, required this.onChanged});

  final TripSortOrder value;
  final ValueChanged<TripSortOrder> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return PopupMenuButton<TripSortOrder>(
      tooltip: 'Ordenar: ${value.label}',
      initialValue: value,
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      itemBuilder: (context) => [
        for (final order in TripSortOrder.values)
          PopupMenuItem<TripSortOrder>(
            value: order,
            child: Row(
              children: [
                Icon(
                  order == value
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 18,
                  color: order == value ? palette.brand : palette.muted,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(order.label)),
              ],
            ),
          ),
      ],
      child: Container(
        width: 34,
        height: 30,
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.line),
        ),
        child: Icon(Icons.sort_rounded, size: 17, color: palette.brand),
      ),
    );
  }
}

class _TripsLoading extends StatelessWidget {
  const _TripsLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 24),
      children: const [
        RoutbSkeleton(height: 150),
        SizedBox(height: 14),
        RoutbSkeleton(height: 150),
        SizedBox(height: 14),
        RoutbSkeleton(height: 150),
      ],
    );
  }
}

class _TripsFailed extends StatelessWidget {
  const _TripsFailed({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 40, 14, 24),
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

/// Historial del pasajero: solo viajes completados y cancelados.
///
/// «Cancelado» agrupa los rechazados, vencidos, cancelados por el pasajero y
/// las rutas que canceló el conductor. Los activos viven en el botón central.
class _HistoryTab extends StatelessWidget {
  const _HistoryTab({
    required this.completed,
    required this.cancelled,
    required this.loading,
    required this.failed,
    required this.onOpen,
    required this.onRefresh,
    required this.onRetry,
  });

  final List<MyRequest> completed;
  final List<MyRequest> cancelled;
  final bool loading;
  final bool failed;
  final ValueChanged<MyRequest> onOpen;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final empty = completed.isEmpty && cancelled.isEmpty;

    return Column(
      children: [
        const RoutbSectionHeader(
          title: 'Historial',
          subtitle: 'Viajes completados y cancelados',
        ),
        Expanded(
          child: loading
              ? const _TripsLoading()
              : failed
              ? _TripsFailed(
                  message: 'No se pudieron cargar tus viajes.',
                  onRetry: onRetry,
                )
              : RefreshIndicator(
                  onRefresh: onRefresh,
                  child: empty
                      ? ListView(
                          key: const PageStorageKey<String>(
                            'passenger-history-empty',
                          ),
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(24),
                          children: const [
                            SizedBox(height: 80),
                            RoutbEmptyState(
                              icon: Icons.history_rounded,
                              message:
                                  'Todavía no tienes viajes completados ni '
                                  'cancelados. Aquí verás los viajes que ya '
                                  'terminaron.',
                            ),
                          ],
                        )
                      : ListView(
                          key: const PageStorageKey<String>(
                            'passenger-history',
                          ),
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                          children: [
                            if (completed.isNotEmpty)
                              _HistorySection(
                                title: 'Completados',
                                icon: Icons.check_circle_outline_rounded,
                                color: palette.mint,
                                requests: completed,
                                onOpen: onOpen,
                              ),
                            if (cancelled.isNotEmpty)
                              _HistorySection(
                                title: 'Cancelados',
                                icon: Icons.cancel_outlined,
                                color: palette.rose,
                                requests: cancelled,
                                onOpen: onOpen,
                              ),
                          ],
                        ),
                ),
        ),
      ],
    );
  }
}

class _HistorySection extends StatelessWidget {
  const _HistorySection({
    required this.title,
    required this.icon,
    required this.color,
    required this.requests,
    required this.onOpen,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<MyRequest> requests;
  final ValueChanged<MyRequest> onOpen;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 7),
                Text(
                  title,
                  style: RoutbText.copy(
                    15,
                    color: palette.ink,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: palette.line),
                  ),
                  child: Text(
                    '${requests.length}',
                    style: RoutbText.copy(
                      11,
                      color: palette.muted,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (final request in requests)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: MyTripCard(request: request, onTap: () => onOpen(request)),
            ),
        ],
      ),
    );
  }
}
