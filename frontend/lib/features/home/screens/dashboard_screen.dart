import 'package:flutter/material.dart';
import 'route_screen.dart';

import '../../../core/models/user_role.dart';
import '../../auth/screens/splash_screen.dart';
import '../../auth/services/auth_api.dart';
import '../services/trip_api.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.role,
    this.userName = 'Estudiante',
  });

  final UserRole role;
  final String userName;

  static const primary = Color(0xFF5271FF);
  static const background = Color(0xFFF4F7FF);
  static const text = Color(0xFF1A2035);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TripApi _tripApi = TripApi();
  List<TripData> _trips = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTrips();
  }

  Future<void> _fetchTrips({String? origin, String? destination}) async {
    setState(() => _isLoading = true);
    try {
      if (widget.role == UserRole.driver) {
        final myTrips = await _tripApi.getMyTrips();
        if (mounted) setState(() => _trips = myTrips);
      } else {
        final available = await _tripApi.getAvailableTrips(
          origin: origin,
          destination: destination,
        );
        if (mounted) setState(() => _trips = available);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar viajes: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout(BuildContext context) async {
    await AuthApi().logout();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (_) => false,
    );
  }

  Future<void> _addNewTrip(String origin, String destination, String time) async {
    try {
      await _tripApi.createTrip(
        origin: origin,
        destination: destination,
        time: time,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Viaje publicado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _fetchTrips();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo publicar el viaje: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _cancelTrip(TripData trip) async {
    try {
      final success = await _tripApi.cancelTrip(trip.id);
      if (success) {
        setState(() {
          _trips.removeWhere((t) => t.id == trip.id);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ruta cancelada correctamente')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cancelar viaje: $e')),
        );
      }
    }
  }

  Future<void> _acceptRequest(TripData trip, TripRequestData request) async {
    try {
      final success = await _tripApi.acceptRequest(request.id);
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Solicitud de ${request.passengerName} aceptada'),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _fetchTrips();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al aceptar solicitud: $e')),
        );
      }
    }
  }

  Future<void> _rejectRequest(TripData trip, TripRequestData request) async {
    try {
      final success = await _tripApi.rejectRequest(request.id);
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Solicitud de ${request.passengerName} rechazada'),
            ),
          );
        }
        await _fetchTrips();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al rechazar solicitud: $e')),
        );
      }
    }
  }

  Future<void> _reserveSeat(TripData trip) async {
    try {
      await _tripApi.requestSeat(trip.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Solicitud de cupo enviada al conductor!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _fetchTrips();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo reservar: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDriver = widget.role == UserRole.driver;
    return Scaffold(
      backgroundColor: DashboardScreen.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(78),
        child: AppBar(
          backgroundColor: DashboardScreen.primary,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
          titleSpacing: 20,
          title: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.route_rounded),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isDriver ? 'MODO CONDUCTOR' : 'MODO PASAJERO',
                    style: const TextStyle(fontSize: 11, letterSpacing: .5),
                  ),
                  Text(
                    'Hola, ${widget.userName} 👋',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: GestureDetector(
                onTap: () => _logout(context),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout_rounded, color: Colors.white, size: 21),
                    Text(
                      'Salir',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _ModeStrip(isDriver: isDriver),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _fetchTrips,
                    child: isDriver
                        ? DriverView(
                            trips: _trips,
                            onCancelTrip: _cancelTrip,
                            onAcceptRequest: _acceptRequest,
                            onRejectRequest: _rejectRequest,
                          )
                        : PassengerView(
                            trips: _trips,
                            onReserve: _reserveSeat,
                            onSearch: (origin, dest) => _fetchTrips(
                              origin: origin,
                              destination: dest,
                            ),
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: isDriver
          ? _PublishTripButton(onTripPublished: _addNewTrip)
          : null,
    );
  }
}

class _ModeStrip extends StatelessWidget {
  const _ModeStrip({required this.isDriver});
  final bool isDriver;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: isDriver ? const Color(0xFF202A4B) : const Color(0xFFEEF1FF),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            Icon(
              isDriver ? Icons.navigation_rounded : Icons.near_me_rounded,
              size: 15,
              color: DashboardScreen.primary,
            ),
            const SizedBox(width: 8),
            Text(
              isDriver ? 'Conduciendo hacia la UTB' : 'Buscando viaje hacia la UTB',
              style: TextStyle(
                color: isDriver ? Colors.white70 : DashboardScreen.primary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
}

class PassengerView extends StatefulWidget {
  const PassengerView({
    super.key,
    required this.trips,
    required this.onReserve,
    required this.onSearch,
  });

  final List<TripData> trips;
  final Function(TripData) onReserve;
  final Function(String, String) onSearch;

  @override
  State<PassengerView> createState() => _PassengerViewState();
}

class _PassengerViewState extends State<PassengerView> {
  final _reserved = <int>{};

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PassengerSearch(onSearch: widget.onSearch),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Viajes disponibles  ${widget.trips.length}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: DashboardScreen.text,
              ),
            ),
          ),
        ),
        Expanded(
          child: widget.trips.isEmpty
              ? ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No hay viajes disponibles',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Aún no hay conductores que hayan publicado una ruta para este destino.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: widget.trips.length,
                  itemBuilder: (context, index) {
                    final trip = widget.trips[index];
                    final reserved = _reserved.contains(trip.id);
                    return _PassengerTripCard(
                      name: trip.driverName ?? 'Conductor UTB',
                      route: '${trip.origin} → ${trip.destination}',
                      time: trip.departureTime,
                      seats: trip.seatsText,
                      rating: 4.8,
                      reviews: '12',
                      reserved: reserved,
                      onReserve: () {
                        setState(() => _reserved.add(trip.id));
                        widget.onReserve(trip);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _PassengerSearch extends StatefulWidget {
  const _PassengerSearch({required this.onSearch});

  final Function(String, String) onSearch;

  @override
  State<_PassengerSearch> createState() => _PassengerSearchState();
}

class _PassengerSearchState extends State<_PassengerSearch> {
  final _originController = TextEditingController();
  final _destController = TextEditingController();

  @override
  void dispose() {
    _originController.dispose();
    _destController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        color: Colors.white,
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.search, color: DashboardScreen.primary, size: 19),
                      SizedBox(width: 8),
                      Text(
                        'Buscar viaje',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      _originController.clear();
                      _destController.clear();
                      widget.onSearch('', '');
                    },
                    child: const Text('Limpiar', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _SearchField(
                hint: 'Origen (ej. Centro)',
                icon: Icons.location_on_rounded,
                controller: _originController,
                onSubmitted: (_) => widget.onSearch(
                  _originController.text,
                  _destController.text,
                ),
              ),
              const SizedBox(height: 8),
              _SearchField(
                hint: 'Destino (ej. UTB)',
                icon: Icons.flag_rounded,
                controller: _destController,
                onSubmitted: (_) => widget.onSearch(
                  _originController.text,
                  _destController.text,
                ),
              ),
            ],
          ),
        ),
      );
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.hint,
    required this.icon,
    this.controller,
    this.onSubmitted,
  });

  final String hint;
  final IconData icon;
  final TextEditingController? controller;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: DashboardScreen.primary, size: 18),
          filled: true,
          fillColor: DashboardScreen.background,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: BorderSide.none,
          ),
        ),
        style: const TextStyle(fontSize: 13),
      );
}

class _PassengerTripCard extends StatelessWidget {
  const _PassengerTripCard({
    required this.name,
    required this.route,
    required this.time,
    required this.seats,
    required this.rating,
    required this.reviews,
    required this.reserved,
    required this.onReserve,
  });

  final String name;
  final String route;
  final String time;
  final String seats;
  final double rating;
  final String reviews;
  final bool reserved;
  final VoidCallback onReserve;

  @override
  Widget build(BuildContext context) => Card(
        color: Colors.white,
        elevation: 1,
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 21,
                    backgroundColor: Color(0xFFE2E8FF),
                    child: Icon(Icons.person, color: DashboardScreen.primary),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.star, size: 15, color: Colors.amber),
                            Text(
                              ' $rating · $reviews reseñas',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _Chip(icon: Icons.route, text: route),
                  ),
                  const SizedBox(width: 6),
                  _Chip(icon: Icons.schedule, text: time),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _SeatBadge(text: '✓  $seats'),
                  ElevatedButton(
                    onPressed: reserved ? null : onReserve,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: reserved
                          ? Colors.grey
                          : DashboardScreen.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(reserved ? 'Solicitado' : 'Reservar cupo'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFEEF1FF),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: DashboardScreen.primary),
            const SizedBox(width: 5),
            Text(
              text,
              style: const TextStyle(fontSize: 11, color: DashboardScreen.text),
            ),
          ],
        ),
      );
}

class _SeatBadge extends StatelessWidget {
  const _SeatBadge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFDDF7E7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.green.shade700,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class DriverView extends StatelessWidget {
  const DriverView({
    super.key,
    required this.trips,
    required this.onCancelTrip,
    required this.onAcceptRequest,
    required this.onRejectRequest,
  });

  final List<TripData> trips;
  final Function(TripData) onCancelTrip;
  final Function(TripData, TripRequestData) onAcceptRequest;
  final Function(TripData, TripRequestData) onRejectRequest;

  void _showCancelDialog(BuildContext context, TripData trip) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Cancelar esta ruta?'),
        content: const Text(
          'El viaje se cancelará en el servidor y se notificará a los pasajeros que hayan solicitado cupo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Volver'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              onCancelTrip(trip);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          const Row(
            children: [
              Icon(Icons.alt_route, color: DashboardScreen.primary),
              SizedBox(width: 8),
              Text(
                'Mis rutas activas',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (trips.isEmpty)
            Card(
              color: Colors.white,
              elevation: 1,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                child: Column(
                  children: [
                    Icon(
                      Icons.directions_car_outlined,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No tienes rutas activas',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Presiona el botón + en la esquina inferior para publicar tu primer viaje.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          else
            ...trips.map(
              (trip) => Card(
                color: Colors.white,
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _Chip(
                                  icon: Icons.route,
                                  text: '${trip.origin} → ${trip.destination}',
                                ),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const RouteScreen(),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.map_outlined,
                                      size: 14),
                                  label: const Text(
                                    'Ver ruta',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDDF7E7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '● ${trip.status.toUpperCase()}',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _Chip(icon: Icons.schedule, text: trip.departureTime),
                          const SizedBox(width: 8),
                          _Chip(icon: Icons.event_seat, text: trip.seatsText),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          const Text(
                            'Solicitudes pendientes',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 8),
                          _CountBadge(count: trip.requests.length),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (trip.requests.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Aún no hay solicitudes de pasajeros para este viaje.',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        )
                      else
                        ...trip.requests.map(
                          (request) => _RequestTile(
                            request: request,
                            onAccept: () => onAcceptRequest(trip, request),
                            onReject: () => onRejectRequest(trip, request),
                          ),
                        ),
                      const SizedBox(height: 14),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: () => _showCancelDialog(context, trip),
                          icon: const Icon(
                            Icons.cancel_outlined,
                            size: 18,
                            color: Colors.redAccent,
                          ),
                          label: const Text(
                            'Cancelar ruta',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 4),
          Text(
            'ⓘ Usa el botón + para publicar un nuevo viaje',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
        ],
      );
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0C2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '$count',
          style: TextStyle(
            color: Colors.orange.shade800,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({
    required this.request,
    required this.onAccept,
    required this.onReject,
  });

  final TripRequestData request;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: DashboardScreen.background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const CircleAvatar(radius: 17, child: Icon(Icons.person, size: 18)),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.passengerName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  if (request.passengerPhone.isNotEmpty)
                    Text(
                      'Tel: ${request.passengerPhone}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Aceptar',
              onPressed: onAccept,
              style: IconButton.styleFrom(backgroundColor: Colors.green),
              color: Colors.white,
              icon: const Icon(Icons.check),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Rechazar',
              onPressed: onReject,
              style: IconButton.styleFrom(backgroundColor: Colors.redAccent),
              color: Colors.white,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      );
}

class _PublishTripButton extends StatelessWidget {
  const _PublishTripButton({required this.onTripPublished});

  final Function(String, String, String) onTripPublished;

  @override
  Widget build(BuildContext context) => FloatingActionButton(
        backgroundColor: DashboardScreen.primary,
        foregroundColor: Colors.white,
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => _PublishTripSheet(onTripPublished: onTripPublished),
        ),
        child: const Icon(Icons.add, size: 30),
      );
}

class _PublishTripSheet extends StatefulWidget {
  const _PublishTripSheet({required this.onTripPublished});

  final Function(String, String, String) onTripPublished;

  @override
  State<_PublishTripSheet> createState() => _PublishTripSheetState();
}

class _PublishTripSheetState extends State<_PublishTripSheet> {
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _timeController = TextEditingController();

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Publicar nuevo viaje',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            _SearchField(
              hint: 'Origen (ej. Centro)',
              icon: Icons.location_on_rounded,
              controller: _originController,
            ),
            const SizedBox(height: 8),
            _SearchField(
              hint: 'Destino (ej. UTB)',
              icon: Icons.flag_rounded,
              controller: _destinationController,
            ),
            const SizedBox(height: 8),
            _SearchField(
              hint: 'Hora de salida (ej. 7:00 AM)',
              icon: Icons.schedule_rounded,
              controller: _timeController,
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: () {
                widget.onTripPublished(
                  _originController.text,
                  _destinationController.text,
                  _timeController.text,
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: DashboardScreen.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Publicar viaje'),
            ),
          ],
        ),
      );
}