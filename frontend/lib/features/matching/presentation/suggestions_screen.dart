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
import '../../../core/widgets/routb_trip_form_page.dart';
import '../../passenger/screens/reserve_seats_screen.dart';
import '../../passenger/widgets/trip_card.dart';

/// Explorador de viajes por sentido y barrio.
///
/// Aquí se investigan viajes, no se pide cupo: el pasajero elige «Hacia UTB» o
/// «Desde UTB» y toca un barrio para ver las salidas que todavía no han
/// ocurrido, hoy y mañana, sin filtrar por una hora concreta.
///
/// La solicitud se hace al tocar un viaje: se abre la pantalla de reserva, que es
/// donde se piden la dirección exacta y los cupos.
class SuggestionsScreen extends StatefulWidget {
  const SuggestionsScreen({
    this.initialDirection,
    this.passengerId,
    this.initialZone,
    this.onSelectionChanged,
    super.key,
  });

  /// `'to_campus'` o `'from_campus'`. Sin valor, empieza hacia la UTB.
  final String? initialDirection;
  final int? passengerId;
  final String? initialZone;
  final void Function(String direction, String? zone)? onSelectionChanged;

  @override
  State<SuggestionsScreen> createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends State<SuggestionsScreen> {
  late String _direction = widget.initialDirection ?? 'to_campus';
  final GlobalKey _resultsKey = GlobalKey();

  List<Trip> _trips = const <Trip>[];
  late String? _zone = widget.initialZone;
  final _search = TextEditingController();
  int _limit = 6;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

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
  List<Trip> get _upcomingTrips {
    final now = DateTime.now();
    final matches = [
      for (final trip in _trips)
        if ((widget.passengerId == null ||
                trip.driverId != widget.passengerId) &&
            !trip.hasDeparted(now) &&
            _goesToCampus(trip) == _toCampus)
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

  String _tripNeighborhood(Trip trip) =>
      Zones.normalize(_toCampus ? trip.origin : trip.destination);

  void _updateSelection(String direction, String? zone) {
    setState(() {
      _direction = direction;
      _zone = zone;
    });
    widget.onSelectionChanged?.call(direction, zone);
  }

  void _selectZone(String zone) {
    FocusManager.instance.primaryFocus?.unfocus();
    _search.clear();
    _limit = 6;
    _updateSelection(_direction, zone);
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
    final result = await openReserveSeatsScreen(context: context, trip: trip);
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

    return RoutbTripFormPage(
      title: '¿A dónde vas?',
      subtitle: 'Viajes de hoy y mañana',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RoutbCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿Hacia dónde viajas?',
                  style: RoutbText.headline(18, color: palette.ink),
                ),
                const SizedBox(height: 12),
                RoutbSegmented<String>(
                  options: const [
                    (value: 'to_campus', label: 'Hacia UTB'),
                    (value: 'from_campus', label: 'Desde UTB'),
                  ],
                  value: _direction,
                  onChanged: (value) => _updateSelection(value, _zone),
                ),
                if (_zone == null) ...[
                  const SizedBox(height: 18),
                  Text(
                    _toCampus ? 'Barrio de salida' : 'Barrio de llegada',
                    style: RoutbText.headline(16, color: palette.ink),
                  ),
                  const SizedBox(height: 8),
                  RoutbField(
                    controller: _search,
                    hint: 'Buscar un barrio',
                    icon: Icons.search_rounded,
                    textInputAction: TextInputAction.search,
                    onChanged: (_) => setState(() => _limit = 6),
                    suffix: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Borrar búsqueda',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => setState(() {
                              _search.clear();
                              _limit = 6;
                            }),
                          ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (_zone == null) _zonePicker(palette) else _results(palette),
        ],
      ),
    );
  }

  Widget _zonePicker(RoutbPalette palette) {
    final query = Zones.normalize(_search.text);
    final names = Zones.neighborhoodNames;
    final List<String> choices;
    if (query.isEmpty) {
      final closest = <String>{};
      for (final trip in _upcomingTrips) {
        final endpoint = _tripNeighborhood(trip);
        for (final name in names) {
          if (endpoint.contains(Zones.normalize(name))) closest.add(name);
          if (closest.length == 3) break;
        }
        if (closest.length == 3) break;
      }
      choices = closest.toList();
    } else {
      choices =
          names.where((name) => Zones.normalize(name).contains(query)).toList()
            ..sort((a, b) {
              final left = Zones.normalize(a);
              final right = Zones.normalize(b);
              if (left.startsWith(query) != right.startsWith(query)) {
                return left.startsWith(query) ? -1 : 1;
              }
              return left.compareTo(right);
            });
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          query.isEmpty
              ? 'Barrios con salidas próximas'
              : 'Barrios encontrados',
          style: RoutbText.headline(18, color: palette.ink),
        ),
        const SizedBox(height: 10),
        if (_failed)
          TextButton.icon(
            onPressed: _retry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar la carga de viajes'),
          ),
        if (query.isEmpty && _loading)
          const LinearProgressIndicator()
        else if (choices.isEmpty && (query.isNotEmpty || !_failed))
          Text(
            query.isEmpty
                ? 'Todavía no hay salidas para este sentido.'
                : 'Ningún barrio coincide. Prueba con otra parte del nombre.',
            style: RoutbText.copy(14, color: palette.muted),
          )
        else if (choices.isNotEmpty)
          Material(
            color: palette.card,
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final name in choices.take(_limit))
                  ListTile(
                    key: ValueKey('barrio-$name'),
                    leading: Icon(Icons.place_outlined, color: palette.brand),
                    title: Text(
                      name,
                      style: RoutbText.headline(16, color: palette.ink),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: palette.muted,
                    ),
                    onTap: () => _selectZone(name),
                  ),
                if (choices.length > _limit)
                  TextButton(
                    onPressed: () => setState(() => _limit += 6),
                    child: const Text('Ver más coincidencias'),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _results(RoutbPalette palette) {
    final zone = _zone!;
    final needle = Zones.normalize(zone);
    final trips = _upcomingTrips
        .where((trip) => _tripNeighborhood(trip).contains(needle))
        .toList();

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
              onPressed: () => _updateSelection(_direction, null),
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
              onPressed: () => _updateSelection(_direction, null),
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
