import 'package:flutter/material.dart';

import '../../../app/dependencies.dart';
import '../../../core/models/trip_suggestion.dart';
import '../../../core/theme/routb_palette.dart';
import '../../../core/theme/routb_text.dart';
import '../../../core/widgets/address_search_field.dart';
import '../../../core/widgets/routb_button.dart';
import '../../../core/widgets/routb_toast.dart';
import '../../trips/data/trip_repository.dart';

class SuggestionsScreen extends StatefulWidget {
  const SuggestionsScreen({this.initialDirection, this.initialDate, super.key});

  final String? initialDirection;
  final DateTime? initialDate;

  @override
  State<SuggestionsScreen> createState() => _SuggestionsScreenState();
}

class _StopDraft {
  SelectedLocation? location;
  int seats = 1;
  String placeType = 'door';
}

class _SuggestionsScreenState extends State<SuggestionsScreen> {
  final List<_StopDraft> _stops = <_StopDraft>[_StopDraft()];
  late String _direction = widget.initialDirection ?? 'to_campus';
  late DateTime _date = DateUtils.dateOnly(widget.initialDate ?? DateTime.now());
  TimeOfDay _time = const TimeOfDay(hour: 7, minute: 0);
  int _seatCount = 1;
  bool _loading = false;
  bool _relaxed = false;
  List<TripSuggestion> _suggestions = const <TripSuggestion>[];

  RoutbDependencies get _dependencies => RoutbScopeDependencies.of(context);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(title: const Text('Encuentra tu viaje')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: <Widget>[
            Text('¿Hacia dónde viajas?', style: RoutbText.headline(20, color: palette.ink)),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const <ButtonSegment<String>>[
                ButtonSegment(value: 'to_campus', label: Text('Hacia UTB')),
                ButtonSegment(value: 'from_campus', label: Text('Desde UTB')),
              ],
              selected: <String>{_direction},
              onSelectionChanged: (value) => setState(() {
                _direction = value.first;
                if (_direction == 'to_campus' && _stops.length > 1) {
                  _stops.removeRange(1, _stops.length);
                }
              }),
            ),
            const SizedBox(height: 14),
            Row(children: <Widget>[
              Expanded(child: OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today),
                label: Text('${_date.day}/${_date.month}/${_date.year}'),
              )),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(
                onPressed: _pickTime,
                icon: const Icon(Icons.schedule),
                label: Text(_time.format(context)),
              )),
            ]),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _seatCount,
              decoration: const InputDecoration(labelText: 'Personas del grupo'),
              items: List<DropdownMenuItem<int>>.generate(
                4,
                (index) => DropdownMenuItem(value: index + 1, child: Text('${index + 1}')),
              ),
              onChanged: (value) => setState(() => _seatCount = value ?? 1),
            ),
            const SizedBox(height: 16),
            for (var index = 0; index < _stops.length; index++) ...[
              Text(
                _direction == 'to_campus' ? 'Punto de recogida' : 'Parada ${index + 1}',
                style: RoutbText.copy(14, color: palette.ink, weight: FontWeight.w700),
              ),
              AddressSearchField(
                key: ValueKey<int>(index),
                geocodeRepository: _dependencies.geocode,
                label: 'Dirección o punto de encuentro',
                onLocationSelected: (location) => setState(() => _stops[index].location = location),
              ),
              if (_direction == 'from_campus')
                DropdownButtonFormField<int>(
                  initialValue: _stops[index].seats,
                  decoration: const InputDecoration(labelText: 'Personas que bajan aquí'),
                  items: List<DropdownMenuItem<int>>.generate(
                    _seatCount,
                    (seatIndex) => DropdownMenuItem(value: seatIndex + 1, child: Text('${seatIndex + 1}')),
                  ),
                  onChanged: (value) => setState(() => _stops[index].seats = value ?? 1),
                ),
              DropdownButtonFormField<String>(
                initialValue: _stops[index].placeType,
                decoration: const InputDecoration(labelText: 'Tipo de punto'),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem(value: 'door', child: Text('En la puerta')),
                  DropdownMenuItem(value: 'meeting_point', child: Text('Punto de encuentro')),
                ],
                onChanged: (value) => setState(() => _stops[index].placeType = value ?? 'door'),
              ),
              if (_direction == 'from_campus' && _stops.length > 1)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _stops.removeAt(index)),
                    icon: const Icon(Icons.remove_circle_outline),
                    label: const Text('Quitar parada'),
                  ),
                ),
              const SizedBox(height: 10),
            ],
            if (_direction == 'from_campus' && _stops.length < _seatCount)
              TextButton.icon(
                onPressed: () => setState(() => _stops.add(_StopDraft())),
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Agregar otra parada'),
              ),
            RoutbButton(
              label: 'Buscar viajes compatibles',
              icon: Icons.search,
              busy: _loading,
              onPressed: _loading ? null : () => _search(relaxed: false),
            ),
            if (_suggestions.isEmpty && !_loading && _relaxed)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: RoutbButton(
                  label: 'Ver más opciones',
                  variant: RoutbButtonVariant.secondary,
                  onPressed: () => _search(relaxed: true),
                ),
              ),
            if (_suggestions.isEmpty && !_loading && !_relaxed)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text('Datos © OpenStreetMap', style: RoutbText.copy(11, color: palette.muted)),
              ),
            const SizedBox(height: 16),
            for (final suggestion in _suggestions) _suggestionCard(suggestion),
            if (_suggestions.isNotEmpty)
              Text('Datos © OpenStreetMap', style: RoutbText.copy(11, color: palette.muted)),
          ],
        ),
      ),
    );
  }

  Widget _suggestionCard(TripSuggestion item) {
    final palette = context.palette;
    final eta = item.etaPickup == null
        ? 'Hora por confirmar'
        : TimeOfDay.fromDateTime(item.etaPickup!.toLocal()).format(context);
    return Card(
      color: palette.card,
      child: ListTile(
        title: Text('${item.origin} → ${item.destination}'),
        subtitle: Text('${item.driverName} · Recogida estimada $eta · Desvío ${item.detourMinutes} min'),
        trailing: Icon(Icons.chevron_right, color: palette.brand),
        onTap: () => _request(item),
      ),
    );
  }

  Future<void> _search({required bool relaxed}) async {
    if (_stops.any((stop) => stop.location == null)) {
      RoutbToast.show(context, 'Completa la dirección de cada parada.');
      return;
    }
    if (_direction == 'from_campus' && _stops.fold<int>(0, (sum, stop) => sum + stop.seats) != _seatCount) {
      RoutbToast.show(context, 'La suma de personas por parada debe ser $_seatCount.');
      return;
    }
    setState(() { _loading = true; _relaxed = relaxed; _suggestions = const <TripSuggestion>[]; });
    try {
      final time = '${_time.hourOfPeriod == 0 ? 12 : _time.hourOfPeriod}:${_time.minute.toString().padLeft(2, '0')} ${_time.period.name.toUpperCase()}';
      final points = _stops.map((stop) => (lat: stop.location!.lat, lng: stop.location!.lng)).toList();
      final result = await _dependencies.matching.suggestions(
        direction: _direction,
        points: points,
        date: _date,
        time: time,
        seatCount: _seatCount,
        relaxed: relaxed,
      );
      if (!mounted) return;
      setState(() { _suggestions = result; _relaxed = !relaxed && result.isEmpty; });
    } on Exception catch (error) {
      if (mounted) RoutbToast.show(context, error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _request(TripSuggestion suggestion) async {
    final requestedAt = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    final stops = <RequestStopInput>[
      for (final stop in _stops)
        RequestStopInput(
          seats: _direction == 'to_campus' ? _seatCount : stop.seats,
          placeType: stop.placeType,
          location: stop.location!,
        ),
    ];
    try {
      await _dependencies.trips.requestSeat(
        suggestion.tripId,
        seatCount: _seatCount,
        requestedAt: requestedAt,
        stops: stops,
      );
      if (mounted) RoutbToast.show(context, 'Solicitud enviada a ${suggestion.driverName}.');
    } on Exception catch (error) {
      if (mounted) RoutbToast.show(context, error.toString());
    }
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateUtils.dateOnly(DateTime.now()),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (value != null && mounted) setState(() => _date = DateUtils.dateOnly(value));
  }

  Future<void> _pickTime() async {
    final value = await showTimePicker(context: context, initialTime: _time);
    if (value != null && mounted) setState(() => _time = value);
  }
}
