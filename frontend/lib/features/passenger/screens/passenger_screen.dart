import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/dependencies.dart';
import '../../../core/models/my_request.dart';
import '../../../core/models/trip.dart';
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
import '../../../core/widgets/routb_seats.dart';
import '../../../core/widgets/routb_sheet.dart';
import '../../../core/widgets/routb_toast.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/screens/auth_flow.dart';
import '../../profile/screens/profile_screen.dart';
import '../../trips/data/trip_repository.dart';
import '../../matching/presentation/suggestions_screen.dart';
import '../widgets/my_trip_card.dart';
import '../widgets/reserve_seats_sheet.dart';
import '../widgets/trip_card.dart';
import 'my_trip_screen.dart';

/// Estado de la lista de viajes del pasajero.
enum PassengerStatus { loading, ready, failed }

enum _PassengerTab { search, myTrips, profile }

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

class _PassengerScreenState extends State<PassengerScreen> {
  final TextEditingController _origin = TextEditingController();
  final TextEditingController _destination = TextEditingController();

  PassengerStatus _status = PassengerStatus.loading;
  List<Trip> _trips = const <Trip>[];
  List<MyRequest> _myRequests = const <MyRequest>[];
  String _errorMessage = '';
  Timer? _debounce;
  bool _filtering = false;
  DateTime _selectedDate = TripSchedule.dateOnly(DateTime.now());
  _PassengerTab _selectedTab = _PassengerTab.search;
  bool _myRequestsLoading = true;
  bool _myRequestsFailed = false;
  int? _busyTripId;
  bool _asked = false;
  ValueNotifier<int>? _refreshSignal;
  VoidCallback? _refreshListener;

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
    if (_refreshSignal != null && _refreshListener != null) {
      _refreshSignal!.removeListener(_refreshListener!);
    }
    _debounce?.cancel();
    _origin.dispose();
    _destination.dispose();
    super.dispose();
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

  Future<void> _loadMyRequests() async {
    if (mounted) {
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
      });
    } on Exception catch (error, stack) {
      logFailure('la carga de mis solicitudes', error, stack);
      if (!mounted) return;
      setState(() {
        _myRequestsLoading = false;
        _myRequestsFailed = true;
      });
    }
  }

  MyRequest? get _currentRequest {
    for (final request in _myRequests) {
      if (request.isActive) return request;
    }
    return null;
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

  Future<void> _selectTab(_PassengerTab tab) async {
    setState(() => _selectedTab = tab);
    if (tab == _PassengerTab.myTrips) await _loadMyRequests();
  }

  Future<void> _clearFilters() async {
    _debounce?.cancel();
    _origin.clear();
    _destination.clear();
    setState(() {
      _selectedDate = TripSchedule.dateOnly(DateTime.now());
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

  Future<void> _logout() async {
    _debounce?.cancel();
    final dependencies = RoutbScopeDependencies.of(context);
    await dependencies.push.logout();
    await dependencies.auth.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      RoutbPageRoute<void>(child: const AuthFlow()),
      (route) => false,
    );
    RoutbToast.show(context, 'Cerraste sesión');
  }

  Future<void> _openSuggestions() =>
      Navigator.of(context)
          .push(RoutbPageRoute<void>(child: const SuggestionsScreen()));

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

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
                    userName: widget.account.name,
                    selectedDate: _selectedDate,
                    currentRequest: _currentRequest,
                    onDateChanged: _setDate,
                    onLogout: _logout,
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
                        trips: () {
                          final confirmedTripIds = _myRequests
                              .where((r) => r.isActive && r.isConfirmed)
                              .map((r) => r.tripId)
                              .toSet();
                          return confirmedTripIds.isEmpty
                              ? _trips
                              : _trips
                                    .where(
                                      (t) => !confirmedTripIds.contains(t.id),
                                    )
                                    .toList(growable: false);
                        }(),
                        myRequest: _currentRequest,
                        busyTripId: _busyTripId,
                        filtering: _filtering,
                        origin: _origin.text.trim(),
                        destination: _destination.text.trim(),
                        selectedDate: _selectedDate,
                        onReserve: _reserve,
                        onOpenMyTrip: _openMyTrip,
                        onRefresh: _load,
                        onClearFilters: _clearFilters,
                      ),
                    },
                  ),
                ],
              ),
              _PassengerTab.myTrips => _MyTripsTab(
                userName: widget.account.name,
                requests: _myRequests,
                loading: _myRequestsLoading,
                failed: _myRequestsFailed,
                onLogout: _logout,
                onRefresh: _loadMyRequests,
                onRetry: _loadMyRequests,
                onOpen: _openMyTrip,
              ),
              _PassengerTab.profile => ProfileScreen(account: widget.account),
            },
          ),
        ),
      ),
      bottomNavigationBar: RoutbNavBar(
        items: [
          const RoutbNavItem(label: 'Buscar', icon: Icons.search_rounded),
          RoutbNavItem(
            label: 'Mis viajes',
            icon: Icons.luggage_outlined,
            badge: _myRequests.where((request) => request.isActive).length,
          ),
          const RoutbNavItem(
            label: 'Perfil',
            icon: Icons.person_outline_rounded,
          ),
        ],
        selectedIndex: _selectedTab.index,
        onSelected: (index) => _selectTab(_PassengerTab.values[index]),
      ),
    );
  }
}

/// Hero del modo pasajero: saludo, mapa (si hay viaje activo) y acceso a búsqueda.
class _PassengerHero extends StatelessWidget {
  const _PassengerHero({
    required this.userName,
    required this.selectedDate,
    required this.onDateChanged,
    required this.onLogout,
    required this.onOpenMap,
    required this.onOpenSuggestions,
    this.currentRequest,
  });

  final String userName;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;
  final VoidCallback onLogout;
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
          HeroBar(
            role: UserRole.passenger,
            userName: userName,
            onLogout: onLogout,
            isDarkBackground: true,
            wave: true,
          ),
          if (active != null) ...[
            const SizedBox(height: 16),
            Stack(
              children: [
                RouteMap(
                  origin: active.origin,
                  destination: active.destination,
                  waypoints: active.waypoints,
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
              borderRadius: BorderRadius.circular(22),
              boxShadow: palette.searchShadow,
            ),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DateQuickPicker(value: selectedDate, onChanged: onDateChanged),
                const SizedBox(height: 10),
                Material(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: onOpenSuggestions,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            size: 20,
                            color: palette.brand,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '¿A dónde vas? Buscar ruta y paradas',
                              style: RoutbText.copy(
                                13,
                                color: palette.ink,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 13,
                            color: palette.muted,
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
    required this.onReserve,
    required this.onOpenMyTrip,
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
  final ValueChanged<Trip> onReserve;
  final ValueChanged<MyRequest> onOpenMyTrip;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onClearFilters;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final now = DateTime.now();
    // Con tarjeta activa el contenido supera la ventana: el estado vacío va
    // en un sliver con caja (desplazable) en vez de rellenar el resto, que lo
    // dejaría sin espacio y sin construir.
    final emptyState = RoutbEmptyState(
      icon: Icons.search_off_rounded,
      message: origin.isEmpty && destination.isEmpty
          ? 'No hay viajes para ${TripSchedule.dateLabel(selectedDate)}. '
                'Prueba con otro día.'
          : 'No hay viajes con esa búsqueda. Prueba con otro origen o '
                'destino.',
      action: RoutbButton(
        label: 'Limpiar búsqueda',
        variant: RoutbButtonVariant.secondary,
        expand: false,
        height: 44,
        onPressed: onClearFilters,
      ),
    );

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
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
                  return RoutbEntrance(
                    index: index,
                    child: TripCard(
                      trip: trip,
                      index: index,
                      isNew: trip.isImminent(now),
                      onReserve:
                          trip.bookingState.isActionable && busyTripId == null
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

/// Vista accesible desde la navegación inferior para consultar todas las
/// solicitudes del pasajero, incluidas las rutas que ya se llenaron.
class _MyTripsTab extends StatelessWidget {
  const _MyTripsTab({
    required this.userName,
    required this.requests,
    required this.loading,
    required this.failed,
    required this.onLogout,
    required this.onRefresh,
    required this.onRetry,
    required this.onOpen,
  });

  final String userName;
  final List<MyRequest> requests;
  final bool loading;
  final bool failed;
  final VoidCallback onLogout;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onRetry;
  final ValueChanged<MyRequest> onOpen;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: palette.heroGradient,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(30),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HeroBar(
                role: UserRole.passenger,
                userName: userName,
                onLogout: onLogout,
                isDarkBackground: true,
                wave: true,
              ),
              const SizedBox(height: 8),
              Text(
                'Mis viajes',
                style: RoutbText.headline(22, color: Colors.white),
              ),
            ],
          ),
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
                  child: requests.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(24),
                          children: const [
                            SizedBox(height: 90),
                            RoutbEmptyState(
                              icon: Icons.luggage_outlined,
                              message: 'Todavía no tienes solicitudes. Cuando pidas cupo, podrás seguir su estado aquí.',
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
                          itemCount: requests.length,
                          itemBuilder: (context, index) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: MyTripCard(
                              request: requests[index],
                              onTap: () => onOpen(requests[index]),
                            ),
                          ),
                        ),
                ),
        ),
      ],
    );
  }
}
