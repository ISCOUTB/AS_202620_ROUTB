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
import '../../../core/widgets/route_map.dart';
import '../../../core/widgets/routb_anim.dart';
import '../../../core/widgets/routb_button.dart';
import '../../../core/widgets/routb_hero.dart';
import '../../../core/widgets/routb_seats.dart';
import '../../../core/widgets/routb_sheet.dart';
import '../../../core/widgets/routb_toast.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/screens/auth_flow.dart';
import '../../trips/data/trip_repository.dart';
import '../widgets/my_trip_card.dart';
import '../widgets/trip_card.dart';
import 'my_trip_screen.dart';

/// Estado de la lista de viajes del pasajero.
enum PassengerStatus { loading, ready, failed }

enum _PassengerTab { search, myTrips }

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

  @override
  void dispose() {
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
    RoutbSheet.show<void>(
      context: context,
      title: 'Trayecto estimado',
      subtitle:
          'El mapa sitúa origen y destino con las coordenadas reales del texto',
      heightFactor: 0.8,
      body: RouteMap(
        origin: _origin.text,
        destination: _destination.text,
        // En la hoja el mapa sí se puede mover: hay sitio de sobra y no compite
        // con el scroll del resto del cuerpo.
        interactive: true,
        height: MediaQuery.sizeOf(context).height * 0.45,
      ),
    );
  }

  void _onQueryChanged(String _) {
    // Se espera a que la persona termine de escribir antes de consultar.
    _debounce?.cancel();
    setState(() => _filtering = true);
    _debounce = Timer(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      unawaited(_load());
    });
  }

  Future<void> _chooseDate() async {
    final today = TripSchedule.dateOnly(DateTime.now());
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(today) ? today : _selectedDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 30)),
      helpText: '¿Qué día viajas?',
      cancelText: 'Cancelar',
      confirmText: 'Elegir día',
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selectedDate = TripSchedule.dateOnly(selected);
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

  Future<void> _reserve(Trip trip) async {
    if (_busyTripId != null) return;
    final maximum = trip.availableSeats.clamp(1, 4).toInt();
    final seatCount = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('¿Para cuántas personas?'),
        children: [
          for (final count in List<int>.generate(maximum, (index) => index + 1))
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(count),
              child: Text(
                '$count ${count == 1 ? 'cupo (solo tú)' : 'cupos (tú y ${count - 1} más)'}',
              ),
            ),
        ],
      ),
    );
    if (seatCount == null || !mounted) return;
    setState(() => _busyTripId = trip.id);

    try {
      final request = await _repository.requestSeat(
        trip.id,
        seatCount: seatCount,
      );
      if (!mounted) return;
      // El backend descuenta los cupos al aceptar el conductor, no al solicitar,
      // así que aquí solo se marca la solicitud en curso.
      _replaceTrip(trip.copyWith(myRequestStatus: request.status));
      // Y con ella aparece la solicitud en «Mis viajes» sin esperar al
      // siguiente refresco.
      unawaited(_loadMyRequests());
      RoutbToast.show(
        context,
        'Solicitud de $seatCount ${seatCount == 1 ? 'cupo' : 'cupos'} enviada a ${trip.hasDriverName ? trip.driverName!.split(' ').first : 'el conductor'}',
      );
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
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: RoutbTheme.contentMaxWidth,
            ),
            child: _selectedTab == _PassengerTab.search
                ? Column(
                    children: [
                      _PassengerHero(
                        userName: widget.account.name,
                        origin: _origin,
                        destination: _destination,
                        selectedDate: _selectedDate,
                        onOriginChanged: _onQueryChanged,
                        onDestinationChanged: _onQueryChanged,
                        onDateTap: _chooseDate,
                        onLogout: _logout,
                        onOpenMap: _openFullMap,
                      ),
                      Expanded(
                        child: switch (_status) {
                          PassengerStatus.loading => const _TripsLoading(),
                          PassengerStatus.failed => _TripsFailed(
                            message: _errorMessage,
                            onRetry: _load,
                          ),
                          PassengerStatus.ready => _TripsList(
                            trips: _trips,
                            busyTripId: _busyTripId,
                            filtering: _filtering,
                            origin: _origin.text.trim(),
                            destination: _destination.text.trim(),
                            selectedDate: _selectedDate,
                            onReserve: _reserve,
                            onRefresh: _load,
                            onClearFilters: _clearFilters,
                          ),
                        },
                      ),
                    ],
                  )
                : _MyTripsTab(
                    userName: widget.account.name,
                    requests: _myRequests,
                    loading: _myRequestsLoading,
                    failed: _myRequestsFailed,
                    onLogout: _logout,
                    onRefresh: _loadMyRequests,
                    onRetry: _loadMyRequests,
                    onOpen: _openMyTrip,
                  ),
          ),
        ),
      ),
      bottomNavigationBar: _PassengerNavigationBar(
        selected: _selectedTab,
        activeTrips: _myRequests.where((request) => request.isActive).length,
        onSelected: _selectTab,
      ),
    );
  }
}

/// Hero del modo pasajero: saludo y buscador.
class _PassengerHero extends StatelessWidget {
  const _PassengerHero({
    required this.userName,
    required this.origin,
    required this.destination,
    required this.selectedDate,
    required this.onOriginChanged,
    required this.onDestinationChanged,
    required this.onDateTap,
    required this.onLogout,
    required this.onOpenMap,
  });

  final String userName;
  final TextEditingController origin;
  final TextEditingController destination;
  final DateTime selectedDate;
  final ValueChanged<String> onOriginChanged;
  final ValueChanged<String> onDestinationChanged;
  final VoidCallback onDateTap;
  final VoidCallback onLogout;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    // Mapa compacto dentro del buscador, y hoja a pantalla casi completa para
    // moverlo. Aquí no hay viaje guardado todavía, solo lo que se está
    // escribiendo, así que el mapa se redibuja con cada búsqueda.
    final originText = origin.text.trim();
    final destinationText = destination.text.trim();

    return Container(
      decoration: BoxDecoration(
        gradient: context.palette.heroGradient,
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
          const SizedBox(height: 16),
          Stack(
            children: [
              RouteMap(
                origin: originText,
                destination: destinationText,
                height: 110,
              ),
              Positioned(
                right: 6,
                top: 6,
                child: Material(
                  color: context.palette.card,
                  borderRadius: BorderRadius.circular(RoutbTheme.radiusPill),
                  child: InkWell(
                    onTap: onOpenMap,
                    borderRadius: BorderRadius.circular(RoutbTheme.radiusPill),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(9, 5, 11, 5),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.fullscreen_rounded,
                            size: 13,
                            color: context.palette.ink,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Abrir mapa',
                            style: RoutbText.copy(
                              11,
                              color: context.palette.ink,
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
          SearchCard(
            origin: origin,
            destination: destination,
            onOriginChanged: onOriginChanged,
            onDestinationChanged: onDestinationChanged,
            selectedDate: selectedDate,
            onDateTap: onDateTap,
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
    required this.busyTripId,
    required this.filtering,
    required this.origin,
    required this.destination,
    required this.selectedDate,
    required this.onReserve,
    required this.onRefresh,
    required this.onClearFilters,
  });

  final List<Trip> trips;
  final int? busyTripId;
  final bool filtering;
  final String origin;
  final String destination;
  final DateTime selectedDate;
  final ValueChanged<Trip> onReserve;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onClearFilters;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final now = DateTime.now();

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
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
            SliverFillRemaining(
              hasScrollBody: false,
              child: RoutbEmptyState(
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
              ),
            )
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

/// Barra compacta que conserva la paleta y las superficies de ROUTB.
class _PassengerNavigationBar extends StatelessWidget {
  const _PassengerNavigationBar({
    required this.selected,
    required this.activeTrips,
    required this.onSelected,
  });

  final _PassengerTab selected;
  final int activeTrips;
  final ValueChanged<_PassengerTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        border: Border(top: BorderSide(color: palette.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _PassengerNavItem(
                label: 'Buscar',
                icon: Icons.search_rounded,
                selected: selected == _PassengerTab.search,
                onTap: () => onSelected(_PassengerTab.search),
              ),
              _PassengerNavItem(
                label: 'Mis viajes',
                icon: Icons.luggage_outlined,
                selected: selected == _PassengerTab.myTrips,
                badge: activeTrips,
                onTap: () => onSelected(_PassengerTab.myTrips),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PassengerNavItem extends StatelessWidget {
  const _PassengerNavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = selected ? palette.brand : palette.muted;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: badge > 0 ? '$label, $badge activos' : label,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? palette.brandSurface : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(icon, size: 20, color: color),
                      if (badge > 0)
                        Positioned(
                          right: -8,
                          top: -5,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: palette.mint,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: const BoxConstraints(minWidth: 15),
                            child: Text(
                              badge > 9 ? '9+' : '$badge',
                              textAlign: TextAlign.center,
                              style: RoutbText.copy(9, color: palette.onMint),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 7),
                  Text(
                    label,
                    style: RoutbText.copy(
                      12,
                      color: color,
                      weight: selected ? FontWeight.w700 : FontWeight.w500,
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
