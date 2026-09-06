import 'package:flutter/material.dart';

import '../../../core/models/user_role.dart';
import '../../auth/screens/splash_screen.dart';
import '../../auth/services/auth_api.dart';

class DashboardScreen extends StatelessWidget {
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

  Future<void> _logout(BuildContext context) async {
    await AuthApi().logout();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDriver = role == UserRole.driver;
    return Scaffold(
      backgroundColor: background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(78),
        child: AppBar(
          backgroundColor: primary,
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
                    'Hola, $userName 👋',
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
            child: isDriver ? const DriverView() : const PassengerView(),
          ),
        ],
      ),
      floatingActionButton: isDriver ? const _PublishTripButton() : null,
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
  const PassengerView({super.key});

  @override
  State<PassengerView> createState() => _PassengerViewState();
}

class _PassengerViewState extends State<PassengerView> {
  final _reserved = <int>{};

  @override
  Widget build(BuildContext context) {
    final trips = [
      (
        'Carlos Mendoza',
        'UTB → Centro Histórico',
        '7:30 AM',
        '2/4 cupos',
        4.8,
        '32',
      ),
      ('Laura Gómez', 'UTB → Bocagrande', '7:45 AM', '1/3 cupos', 4.9, '58'),
      ('Andrés Torres', 'UTB → El Recreo', '8:00 AM', '3/4 cupos', 4.6, '17'),
    ];
    return Column(
      children: [
        const _PassengerSearch(),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Viajes disponibles  3',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: DashboardScreen.text,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: trips.length,
            itemBuilder: (context, index) {
              final trip = trips[index];
              final reserved = _reserved.contains(index);
              return _PassengerTripCard(
                name: trip.$1,
                route: trip.$2,
                time: trip.$3,
                seats: trip.$4,
                rating: trip.$5,
                reviews: trip.$6,
                reserved: reserved,
                onReserve: () => setState(() {
                  if (reserved) {
                    _reserved.remove(index);
                  } else {
                    _reserved.add(index);
                  }
                }),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PassengerSearch extends StatelessWidget {
  const _PassengerSearch();

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
          const SizedBox(height: 10),
          _SearchField(hint: 'Origen', icon: Icons.location_on_rounded),
          const SizedBox(height: 8),
          _SearchField(hint: 'Destino', icon: Icons.flag_rounded),
          const SizedBox(height: 8),
          _SearchField(
            hint: 'Hora (ej. 7:30 AM)',
            icon: Icons.schedule_rounded,
          ),
        ],
      ),
    ),
  );
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.hint, required this.icon});
  final String hint;
  final IconData icon;

  @override
  Widget build(BuildContext context) => TextField(
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
              const _SeatBadge(text: '✓  2/4 cupos'),
              ElevatedButton(
                onPressed: onReserve,
                style: ElevatedButton.styleFrom(
                  backgroundColor: reserved
                      ? Colors.green
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
                child: Text(reserved ? 'Reservado' : 'Reservar cupo'),
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

class DriverView extends StatefulWidget {
  const DriverView({super.key});

  @override
  State<DriverView> createState() => _DriverViewState();
}

class _DriverViewState extends State<DriverView> {
  final _requests = <String>['Sofía Ruiz', 'Miguel Pérez'];

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
      Card(
        color: Colors.white,
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const _Chip(icon: Icons.route, text: 'Centro → UTB'),
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
                      '● Activo',
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
              const Row(
                children: [
                  _Chip(icon: Icons.schedule, text: '7:00 AM'),
                  SizedBox(width: 8),
                  _Chip(icon: Icons.event_seat, text: '2/4 cupos'),
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
                  _CountBadge(count: _requests.length),
                ],
              ),
              const SizedBox(height: 8),
              ..._requests.map(
                (request) => _RequestTile(
                  name: request,
                  onAccept: () => setState(() => _requests.remove(request)),
                  onReject: () => setState(() => _requests.remove(request)),
                ),
              ),
            ],
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
    required this.name,
    required this.onAccept,
    required this.onReject,
  });
  final String name;
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
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              Text(
                '⌖ Centro Histórico',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
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
  const _PublishTripButton();

  @override
  Widget build(BuildContext context) => FloatingActionButton(
    backgroundColor: DashboardScreen.primary,
    foregroundColor: Colors.white,
    onPressed: () => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _PublishTripSheet(),
    ),
    child: const Icon(Icons.add, size: 30),
  );
}

class _PublishTripSheet extends StatelessWidget {
  const _PublishTripSheet();

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
        const _SearchField(hint: 'Origen', icon: Icons.location_on_rounded),
        const SizedBox(height: 8),
        const _SearchField(hint: 'Destino', icon: Icons.flag_rounded),
        const SizedBox(height: 8),
        const _SearchField(
          hint: 'Hora de salida',
          icon: Icons.schedule_rounded,
        ),
        const SizedBox(height: 14),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
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
