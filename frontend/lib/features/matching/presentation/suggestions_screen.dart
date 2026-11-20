import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/dependencies.dart';
import '../../../core/constants/zones.dart';
import '../../../core/models/trip.dart';
import '../../../core/models/trip_schedule.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/routb_palette.dart';
import '../../../core/theme/routb_text.dart';
import '../../../core/widgets/routb_button.dart';
import '../../../core/widgets/routb_card.dart';
import '../../../core/widgets/routb_field.dart';
import '../../../core/widgets/routb_seats.dart';
import '../../../core/widgets/routb_sheet.dart';
import '../../../core/widgets/routb_toast.dart';
import '../../passenger/widgets/reserve_seats_sheet.dart';
import '../../passenger/widgets/trip_card.dart';

/// Explorador de viajes por sentido y barrio.
///
/// Aquí se investigan viajes, no se pide cupo: el pasajero elige «Hacia UTB» o
/// «Desde UTB» y toca un barrio para ver las salidas que todavía no han
/// ocurrido, hoy y mañana, sin filtrar por una hora concreta.
///
/// La solicitud se hace al tocar un viaje: se abre la hoja de reserva, que es
/// donde se piden la dirección exacta y los cupos.
class SuggestionsScreen extends StatefulWidget {
  const SuggestionsScreen({this.initialDirection, super.key});

  /// `'to_campus'` o `'from_campus'`. Sin valor, empieza hacia la UTB.
  final String? initialDirection;

  @override
  State<SuggestionsScreen> createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends State<SuggestionsScreen> {
  late String _direction = widget.initialDirection ?? 'to_campus';
  final GlobalKey _resultsKey = GlobalKey();

  List<Trip> _trips = const <Trip>[];
  String? _zone;
  bool _loading = true;
  bool _failed = false;
  bool _asked = false;

  bool get _toCampus => _direction == 'to_campus';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_asked) return;
    _asked = true;
    unawaited(_load());
  }

  /// Carga hoy y mañana de una sola vez.
  ///
  /// El filtro por barrio se resuelve en el cliente sobre esta lista, así que
  /// tocar un barrio no depende de una hora ni de otra llamada al backend.
  Future<void> _load() async {
    try {
      final repository = RoutbScopeDependencies.of(context).trips;
      final today = TripSchedule.dateOnly(DateTime.now());
      final tomorrow = today.add(const Duration(days: 1));
      final days = await Future.wait(<Future<List<Trip>>>[
        repository.listAvailable(departureDate: today),
        repository.listAvailable(departureDate: tomorrow),
      ]);
      if (!mounted) return;
      setState(() {
        _trips = <Trip>[...days[0], ...days[1]];
        _loading = false;
        _failed = false;
      });
    } on Exception catch (error, stack) {
      logFailure('la búsqueda de viajes por barrio', error, stack);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void _retry() {
    setState(() {
      _loading = true;
      _failed = false;
    });
    unawaited(_load());
  }

  /// Viajes que salen desde ese momento en adelante para el barrio elegido.
  List<Trip> get _visibleTrips {
    final zone = _zone;
    if (zone == null) return const <Trip>[];

    final needle = Zones.normalize(zone);
    final now = DateTime.now();
    final matches = <Trip>[
      for (final trip in _trips)
        if (!trip.hasDeparted(now) &&
            _goesToCampus(trip) == _toCampus &&
            Zones.normalize(_toCampus ? trip.origin : trip.destination)
                .contains(needle))
          trip,
    ];

    // Se ordena por el momento real de salida, no solo por la hora del día:
    // así los viajes de mañana quedan después de los de hoy.
    matches.sort((a, b) {
      final left = a.departureDateTime;
      final right = b.departureDateTime;
      if (left == null && right == null) return a.id.compareTo(b.id);
      if (left == null) return 1;
      if (right == null) return -1;
      final byMoment = left.compareTo(right);
      return byMoment != 0 ? byMoment : a.id.compareTo(b.id);
    });
    return matches;
  }

  /// `true` si el viaje termina en la UTB.
  ///
  /// Los viajes antiguos pueden no traer `direction`, así que se cae al texto
  /// del destino.
  bool _goesToCampus(Trip trip) {
    if (trip.direction == 'to_campus') return true;
    if (trip.direction == 'from_campus') return false;
    return Zones.isCampus(trip.destination) ||
        trip.destination.toLowerCase().contains('utb');
  }

  void _selectZone(String zone) {
    setState(() => _zone = zone);
    // La lista de barrios es larga: al elegir uno se sustituye por los
    // resultados, y este ajuste lleva la vista al encabezado de la lista.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final results = _resultsKey.currentContext;
      if (results == null) return;
      Scrollable.ensureVisible(
        results,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        alignment: 0.02,
      );
    });
  }

  Future<void> _reserve(Trip trip) async {
    final result = await showReserveSeatsSheet(context: context, trip: trip);
    if (result == null || !mounted) return;

    final seats = result.seatCount;
    final driver = trip.hasDriverName
        ? trip.driverName!.split(' ').first
        : 'el conductor';
    RoutbToast.show(
      context,
      'Solicitud de $seats ${seats == 1 ? 'cupo' : 'cupos'} enviada a $driver',
    );
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(title: const Text('Encuentra tu viaje')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: <Widget>[
            RoutbCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '¿Hacia dónde viajas?',
                    style: RoutbText.headline(18, color: palette.ink),
                  ),
                  const SizedBox(height: 12),
                  RoutbSegmented<String>(
                    options: const <({String value, String label})>[
                      (value: 'to_campus', label: 'Hacia UTB'),
                      (value: 'from_campus', label: 'Desde UTB'),
                    ],
                    value: _direction,
                    onChanged: (value) => setState(() => _direction = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_zone == null) _zonePicker(palette) else _results(palette),
          ],
        ),
      ),
    );
  }

  /// Catálogo completo de barrios. Al tocar uno se filtra la lista de viajes.
  Widget _zonePicker(RoutbPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Elige tu barrio',
          style: RoutbText.headline(16, color: palette.ink),
        ),
        const SizedBox(height: 4),
        Text(
          _toCampus
              ? 'Verás los viajes que salen de ese barrio hacia la UTB.'
              : 'Verás los viajes que llegan a ese barrio desde la UTB.',
          style: RoutbText.copy(12.5, color: palette.muted, height: 1.4),
        ),
        if (_failed) ...<Widget>[
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'No se pudieron cargar los viajes.',
                  style: RoutbText.copy(12.5, color: palette.rose),
                ),
              ),
              TextButton(onPressed: _retry, child: const Text('Reintentar')),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final name in Zones.neighborhoodNames)
              RoutbChip(
                key: ValueKey<String>('barrio-$name'),
                label: name,
                selected: false,
                onTap: () => _selectZone(name),
              ),
          ],
        ),
      ],
    );
  }

  Widget _results(RoutbPalette palette) {
    final zone = _zone!;
    final trips = _visibleTrips;

    return Column(
      key: _resultsKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                _toCampus ? 'Desde $zone' : 'Hacia $zone',
                style: RoutbText.headline(16, color: palette.ink),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _zone = null),
              child: const Text('Cambiar barrio'),
            ),
          ],
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_failed)
          RoutbEmptyState(
            icon: Icons.cloud_off_rounded,
            message: 'No se pudieron cargar los viajes.',
            action: RoutbButton(
              label: 'Reintentar',
              icon: Icons.refresh_rounded,
              variant: RoutbButtonVariant.secondary,
              expand: false,
              height: 44,
              onPressed: _retry,
            ),
          )
        else if (trips.isEmpty)
          RoutbEmptyState(
            icon: Icons.search_off_rounded,
            message: _toCampus
                ? 'No hay viajes desde $zone por ahora. Prueba con otro barrio.'
                : 'No hay viajes hacia $zone por ahora. Prueba con otro barrio.',
            action: RoutbButton(
              label: 'Elegir otro barrio',
              variant: RoutbButtonVariant.secondary,
              expand: false,
              height: 44,
              onPressed: () => setState(() => _zone = null),
            ),
          )
        else ...<Widget>[
          Text(
            trips.length == 1
                ? '1 viaje disponible'
                : '${trips.length} viajes disponibles',
            style: RoutbText.copy(12, color: palette.muted),
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < trips.length; index++)
            TripCard(
              trip: trips[index],
              index: index,
              onReserve: () => _reserve(trips[index]),
            ),
        ],
      ],
    );
  }
}
