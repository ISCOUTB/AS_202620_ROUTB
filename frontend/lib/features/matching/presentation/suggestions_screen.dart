import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/dependencies.dart';
import '../../../core/models/trip_schedule.dart';
import '../../../core/models/trip_suggestion.dart';
import '../../../core/theme/routb_palette.dart';
import '../../../core/theme/routb_text.dart';
import '../../../core/widgets/address_search_field.dart';
import '../../../core/widgets/date_quick_picker.dart';
import '../../../core/widgets/routb_button.dart';
import '../../../core/widgets/routb_card.dart';
import '../../../core/widgets/routb_sheet.dart';
import '../../../core/widgets/routb_toast.dart';
import '../../trips/data/trip_repository.dart';
import 'suggestions_map.dart';

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
  late DateTime _date = TripSchedule.clampToTripWindow(
    widget.initialDate ?? DateTime.now(),
  );
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
                    onChanged: (value) => setState(() {
                      _direction = value;
                      if (_direction == 'to_campus' && _stops.length > 1) {
                        _stops.removeRange(1, _stops.length);
                      }
                    }),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      DateQuickPicker(
                        value: _date,
                        onChanged: (value) => setState(() => _date = value),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Material(
                          color: palette.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(99),
                            side: BorderSide(color: palette.line),
                          ),
                          child: InkWell(
                            onTap: _pickTime,
                            borderRadius: BorderRadius.circular(99),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Icon(
                                    Icons.schedule_rounded,
                                    size: 16,
                                    color: palette.brand,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      _time.format(context),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: RoutbText.copy(
                                        12.5,
                                        color: palette.ink,
                                        weight: FontWeight.w700,
                                      ),
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
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    initialValue: _seatCount,
                    decoration: InputDecoration(
                      labelText: 'Personas del grupo',
                      filled: true,
                      fillColor: palette.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: palette.line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: palette.line),
                      ),
                    ),
                    items: List<DropdownMenuItem<int>>.generate(
                      4,
                      (index) => DropdownMenuItem(
                        value: index + 1,
                        child: Text('${index + 1}'),
                      ),
                    ),
                    onChanged: (value) =>
                        setState(() => _seatCount = value ?? 1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            for (var index = 0; index < _stops.length; index++) ...[
              RoutbCard(
                margin: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _direction == 'to_campus'
                          ? 'Punto de recogida'
                          : 'Parada ${index + 1}',
                      style: RoutbText.headline(16, color: palette.ink),
                    ),
                    const SizedBox(height: 8),
                    AddressSearchField(
                      key: ValueKey<int>(index),
                      toCampus: _direction == 'to_campus',
                      label: _direction == 'to_campus'
                          ? 'Escribe dirección o barrio de recogida'
                          : 'Escribe dirección o barrio de bajada',
                      onLocationSelected: (location) =>
                          setState(() => _stops[index].location = location),
                      onLocationCleared: () =>
                          setState(() => _stops[index].location = null),
                    ),
                    if (_direction == 'from_campus') ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: _stops[index].seats,
                        decoration: InputDecoration(
                          labelText: 'Personas que bajan aquí',
                          filled: true,
                          fillColor: palette.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: palette.line),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: palette.line),
                          ),
                        ),
                        items: List<DropdownMenuItem<int>>.generate(
                          _seatCount,
                          (seatIndex) => DropdownMenuItem(
                            value: seatIndex + 1,
                            child: Text('${seatIndex + 1}'),
                          ),
                        ),
                        onChanged: (value) =>
                            setState(() => _stops[index].seats = value ?? 1),
                      ),
                    ],
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _stops[index].placeType,
                      decoration: InputDecoration(
                        labelText: 'Tipo de punto',
                        filled: true,
                        fillColor: palette.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: palette.line),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: palette.line),
                        ),
                      ),
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem(
                          value: 'door',
                          child: Text('En la puerta'),
                        ),
                        DropdownMenuItem(
                          value: 'meeting_point',
                          child: Text('Punto de encuentro'),
                        ),
                      ],
                      onChanged: (value) => setState(
                        () => _stops[index].placeType = value ?? 'door',
                      ),
                    ),
                    if (_direction == 'from_campus' && _stops.length > 1)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () =>
                              setState(() => _stops.removeAt(index)),
                          icon: const Icon(Icons.remove_circle_outline),
                          label: const Text('Quitar parada'),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (_direction == 'from_campus' && _stops.length < _seatCount)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextButton.icon(
                  onPressed: () => setState(() => _stops.add(_StopDraft())),
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('Agregar otra parada'),
                ),
              ),
            RoutbButton(
              label: 'Buscar viajes compatibles',
              icon: Icons.search_rounded,
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
                padding: const EdgeInsets.only(top: 12),
                child: Center(
                  child: Text(
                    'Datos © OpenStreetMap',
                    style: RoutbText.copy(11, color: palette.muted),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            if (_suggestions.isNotEmpty) ...[
              SuggestionsMap(
                suggestions: _suggestions,
                passengerPoints: <LatLng>[
                  for (final stop in _stops)
                    if (stop.location != null)
                      LatLng(stop.location!.lat, stop.location!.lng),
                ],
              ),
              const SizedBox(height: 12),
            ],
            for (final suggestion in _suggestions) _suggestionCard(suggestion),
            if (_suggestions.isNotEmpty)
              Center(
                child: Text(
                  'Datos © OpenStreetMap',
                  style: RoutbText.copy(11, color: palette.muted),
                ),
              ),
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
    return RoutbCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: () => _request(item),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${item.origin} → ${item.destination}',
                  style: RoutbText.headline(15, color: palette.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.driverName} · Recogida estimada $eta · Desvío ${item.detourMinutes} min',
                  style: RoutbText.copy(12, color: palette.muted),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: palette.brand),
        ],
      ),
    );
  }

  Future<void> _search({required bool relaxed}) async {
    if (_stops.any((stop) => stop.location == null)) {
      RoutbToast.show(context, 'Completa la dirección de cada parada.');
      return;
    }
    if (_direction == 'from_campus' &&
        _stops.fold<int>(0, (sum, stop) => sum + stop.seats) != _seatCount) {
      RoutbToast.show(
        context,
        'La suma de personas por parada debe ser $_seatCount.',
      );
      return;
    }
    setState(() {
      _loading = true;
      _relaxed = relaxed;
      _suggestions = const <TripSuggestion>[];
    });
    try {
      final time =
          '${_time.hourOfPeriod == 0 ? 12 : _time.hourOfPeriod}:${_time.minute.toString().padLeft(2, '0')} ${_time.period.name.toUpperCase()}';
      final points = _stops
          .map((stop) => (lat: stop.location!.lat, lng: stop.location!.lng))
          .toList();
      final result = await _dependencies.matching.suggestions(
        direction: _direction,
        points: points,
        date: _date,
        time: time,
        seatCount: _seatCount,
        relaxed: relaxed,
      );
      if (!mounted) return;
      setState(() {
        _suggestions = result;
        _relaxed = !relaxed && result.isEmpty;
      });
    } on Exception catch (error) {
      if (mounted) RoutbToast.show(context, error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _request(TripSuggestion suggestion) async {
    final requestedAt = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );
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
      if (mounted) {
        RoutbToast.show(
          context,
          'Solicitud enviada a ${suggestion.driverName}.',
        );
      }
    } on Exception catch (error) {
      if (mounted) RoutbToast.show(context, error.toString());
    }
  }

  Future<void> _pickTime() async {
    final value = await showTimePicker(context: context, initialTime: _time);
    if (value != null && mounted) setState(() => _time = value);
  }
}
