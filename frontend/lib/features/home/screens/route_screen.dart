import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class RouteScreen extends StatefulWidget {
  const RouteScreen({super.key});

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  final MapController _mapController = MapController();

  bool viajeIniciado = false;
  int posicionCarro = 0;
  Timer? timer;

  final List<LatLng> ruta = [
    LatLng(10.4236, -75.5477),
    LatLng(10.4215, -75.5448),
    LatLng(10.4188, -75.5410),
    LatLng(10.4160, -75.5370),
    LatLng(10.4130, -75.5330),
    LatLng(10.4100, -75.5290),
    LatLng(10.4070, -75.5250),
    LatLng(10.4050, -75.5210),
    LatLng(10.4030, -75.5170),
  ];

  void iniciarViaje() {
    setState(() {
      viajeIniciado = true;
      posicionCarro = 0;
    });

    timer?.cancel();

    timer = Timer.periodic(
      const Duration(milliseconds: 900),
      (timer) {
        if (posicionCarro < ruta.length - 1) {
          setState(() {
            posicionCarro++;
          });

          _mapController.move(
            ruta[posicionCarro],
            14.5,
          );
        } else {
          timer.cancel();

          setState(() {
            viajeIniciado = false;
          });

          _mostrarLlegada();
        }
      },
    );
  }

  void _mostrarLlegada() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¡Llegaste a la UTB!'),
        content: const Text(
          'El recorrido ha finalizado correctamente.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final posicionActual = ruta[posicionCarro];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF5271FF),
        foregroundColor: Colors.white,
        title: const Text(
          'Tu ruta de hoy',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(10.415, -75.535),
              initialZoom: 13.5,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName:
                    'com.example.frontend',
              ),

              PolylineLayer(
                polylines: [
                  Polyline(
                    points: ruta,
                    strokeWidth: 6,
                    color: const Color(0xFF5271FF),
                  ),
                ],
              ),

              MarkerLayer(
                markers: [
                  Marker(
                    point: ruta.first,
                    width: 55,
                    height: 65,
                    child: Column(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Colors.blue,
                          size: 40,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          color: Colors.white,
                          child: const Text(
                            'Centro',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Marker(
                    point: ruta.last,
                    width: 55,
                    height: 65,
                    child: Column(
                      children: [
                        const Icon(
                          Icons.school,
                          color: Colors.indigo,
                          size: 38,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          color: Colors.white,
                          child: const Text(
                            'UTB',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Marker(
                    point: posicionActual,
                    width: 60,
                    height: 60,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.directions_car,
                        color: Color(0xFF5271FF),
                        size: 30,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          Positioned(
            top: 15,
            left: 15,
            right: 15,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    viajeIniciado
                        ? Icons.navigation
                        : Icons.route,
                    color: const Color(0xFF5271FF),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          viajeIniciado
                              ? 'Viaje en curso'
                              : 'Ruta disponible',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Centro Histórico → UTB',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (viajeIniciado)
                    const Text(
                      '🚗',
                      style: TextStyle(fontSize: 25),
                    ),
                ],
              ),
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                20,
                20,
                20,
                25,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(25),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Centro Histórico',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_forward),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.school,
                        color: Colors.indigo,
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'UTB',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 15),

                  Row(
                    children: [
                      Expanded(
                        child: _Info(
                          icon: Icons.people,
                          title: 'Pasajeros',
                          value: '2/4',
                        ),
                      ),
                      Expanded(
                        child: _Info(
                          icon: Icons.access_time,
                          title: 'Hora',
                          value: '7:00 AM',
                        ),
                      ),
                      Expanded(
                        child: _Info(
                          icon: Icons.timer,
                          title: 'Duración',
                          value: '20 min',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed:
                          viajeIniciado ? null : iniciarViaje,
                      icon: Icon(
                        viajeIniciado
                            ? Icons.directions_car
                            : Icons.play_arrow,
                      ),
                      label: Text(
                        viajeIniciado
                            ? 'Viaje en curso...'
                            : 'Iniciar viaje',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(0xFF5271FF),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            Colors.blue.shade200,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          color: const Color(0xFF5271FF),
          size: 21,
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 11,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
