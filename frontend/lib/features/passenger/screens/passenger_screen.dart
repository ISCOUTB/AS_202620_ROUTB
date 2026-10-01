import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/dependencies.dart';
import '../../../core/models/my_request.dart';
import '../../../core/models/trip.dart';
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
    setState(() {
      _status = PassengerStatus.loading;
      _errorMessage = '';
    });

    try {
      final trips = await _repository.listAvailable(
        origin: _origin.text,
        destination: _destination.text,
      );
      if (!mounted) return;
      setState(() {
        _trips = trips;
        _status = PassengerStatus.ready;
      });
      // Las solicitudes propias van aparte: si fallan, el buscador sigue
      // funcionando y solo se pierde la tarjeta de «Mi viaje».
      unawaited(_loadMyRequests());
    } on Exception catch (error, stack) {
      logFailure('la carga de viajes', error, stack);
      if (!mounted) return;
      setState(() {
        _status = PassengerStatus.failed;
        _errorMessage = describeFailure(error);
      });
    }
  }

  Future<void> _loadMyRequests() async {
    try {
      final requests = await _repository.myRequests();
      if (!mounted) return;
      setState(() => _myRequests = requests);
    } on Exception catch (error, stack) {
      logFailure('la carga de mis solicitudes', error, stack);
    }
  }

  /// La solicitud viva que se muestra en la tarjeta: la más reciente que sigue
  /// en curso o confirmada.
  ///
  /// Las rechazadas se dejan fuera a propósito: no tienen cupo, así que no
  /// describen un viaje, y `POST /requests/trips/{id}` vuelve a admitirlas.
  MyRequest? get _currentRequest {
    for (final request in _myRequests) {
      if (request.isActive) return request;
    }
    return null;
  }

  void _openMyTrip(MyRequest request) {
    unawaited(
      Navigator.of(context).push(
        RoutbPageRoute<void>(
          child: MyTripScreen(
            request: request,
            onWithdrawn: () {
              unawaited(_loadMyRequests());
              unawaited(_load());
            },
          ),
        ),
      ),
    );
  }

  void _openFullMap() {
    RoutbSheet.show<void>(
      context: context,
      title: 'Trayecto estimado',
      subtitle:
          'La línea une los dos barrios del catálogo, no es un ruteo real',
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
      setState(() => _filtering = false);
      unawaited(_load());
    });
  }

  Future<void> _reserve(Trip trip) async {
    if (_busyTripId != null) return;
    setState(() => _busyTripId = trip.id);

    try {
      final request = await _repository.requestSeat(trip.id);
      if (!mounted) return;
      // El backend descuenta el cupo al aceptar el conductor, no al solicitar, así
      // que aquí solo se marca la solicitud en curso.
      _replaceTrip(trip.copyWith(myRequestStatus: request.status));
      // Y con ella aparece la tarjeta de «Mi viaje» de una vez, sin esperar al
      // siguiente refresco del buscador.
      unawaited(_loadMyRequests());
      RoutbToast.show(
        context,
        'Solicitud enviada a ${trip.hasDriverName ? trip.driverName!.split(' ').first : 'el conductor'}',
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
        child: LayoutBuilder(
          builder: (context, constraints) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: RoutbTheme.contentMaxWidth,
              ),
              child: Column(
                children: [
                  _PassengerHero(
                    userName: widget.account.name,
                    origin: _origin,
                    destination: _destination,
                    onOriginChanged: _onQueryChanged,
                    onDestinationChanged: _onQueryChanged,
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
                        myRequest: _currentRequest,
                        onOpenMyTrip: _openMyTrip,
                        onReserve: _reserve,
                        onRefresh: _load,
                      ),
                    },
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

/// Hero del modo pasajero: saludo y buscador.
class _PassengerHero extends StatelessWidget {
  const _PassengerHero({
    required this.userName,
    required this.origin,
    required this.destination,
    required this.onOriginChanged,
    required this.onDestinationChanged,
    required this.onLogout,
    required this.onOpenMap,
  });

  final String userName;
  final TextEditingController origin;
  final TextEditingController destination;
  final ValueChanged<String> onOriginChanged;
  final ValueChanged<String> onDestinationChanged;
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
    required this.myRequest,
    required this.onOpenMyTrip,
    required this.onReserve,
    required this.onRefresh,
  });

  final List<Trip> trips;
  final int? busyTripId;
  final bool filtering;
  final String origin;
  final String destination;
  final MyRequest? myRequest;
  final ValueChanged<MyRequest> onOpenMyTrip;
  final ValueChanged<Trip> onReserve;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final now = DateTime.now();

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // La tarjeta va antes que el encabezado, incluso con cero resultados:
          // el viaje confirmado desaparece del listado cuando se llena, que es
          // justo cuando el pasajero necesita verlo.
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
            SliverFillRemaining(
              hasScrollBody: false,
              child: RoutbEmptyState(
                icon: Icons.search_off_rounded,
                message: origin.isEmpty && destination.isEmpty
                    ? 'Todavía no hay ningún viaje publicado. Vuelve en un '
                          'ratito o crea el tuyo como conductor.'
                    : 'No hay viajes con esa búsqueda. Prueba con otro origen o '
                          'destino.',
                action: (origin.isEmpty && destination.isEmpty)
                    ? null
                    : RoutbButton(
                        label: 'Quitar el filtro',
                        variant: RoutbButtonVariant.secondary,
                        expand: false,
                        height: 44,
                        onPressed: null,
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
