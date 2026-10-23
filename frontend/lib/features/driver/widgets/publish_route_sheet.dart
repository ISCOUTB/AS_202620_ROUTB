import 'package:flutter/material.dart';

import '../../../core/constants/zones.dart';
import '../../../core/models/travel_time.dart';
import '../../../core/models/trip_schedule.dart';
import '../../../core/theme/routb_palette.dart';
import '../../../core/theme/routb_text.dart';
import '../../../core/widgets/address_search_field.dart';
import '../../../core/widgets/date_quick_picker.dart';
import '../../../core/widgets/routb_button.dart';
import '../../../core/widgets/routb_card.dart';
import '../../../core/widgets/routb_field.dart';
import '../../../core/widgets/routb_seats.dart';
import '../../../core/widgets/routb_sheet.dart';

/// Ruta en construcción dentro de la hoja de publicación.
///
/// Se va mutando mientras la persona ajusta el formulario, y la vista previa se
/// redibuja en cada cambio, igual que en el diseño.
class DraftRoute {
  DraftRoute({
    required this.driverName,
    required this.driverInitials,
    Zone? zone,
    this.toCampus = true,
    TravelTime? departure,
    DateTime? departureDate,
    this.seats = 3,
    this.meetingPoint = '',
    this.driverPoint,
  }) : zone = zone ?? Zones.neighborhoods.first,
       departure = departure ?? const TravelTime.fromClock(7, 30),
       departureDate =
           departureDate ??
           TripSchedule.nextOccurrence(
             departure ?? const TravelTime.fromClock(7, 30),
           );

  /// Barrio del trayecto.
  Zone zone;

  /// `true` si va hacia la universidad, `false` si sale de ella.
  bool toCampus;

  /// Hora de salida.
  TravelTime departure;

  /// Día concreto para el que se publica la ruta.
  DateTime departureDate;

  /// Número de cupos ofrecidos, de 1 a 4.
  int seats;

  /// Punto de encuentro descrito para los pasajeros.
  String meetingPoint;

  /// Dirección exacta elegida en el mapa, si la persona la proporciona.
  SelectedLocation? driverPoint;

  /// Nombre del conductor, para la vista previa.
  final String driverName;

  /// Iniciales del conductor, para la vista previa.
  final String driverInitials;

  /// Barrio de partida.
  String get origin => toCampus
      ? (driverPoint != null && driverPoint!.addressText.trim().isNotEmpty
            ? driverPoint!.addressText.trim()
            : zone.name)
      : Zones.campus.name;

  /// Barrio de llegada.
  String get destination => toCampus
      ? Zones.campus.name
      : (driverPoint != null && driverPoint!.addressText.trim().isNotEmpty
            ? driverPoint!.addressText.trim()
            : zone.name);

  /// Texto del trayecto, como lo muestra el conductor.
  String get routeLabel => '$origin → $destination';

  /// Llegada estimada según los minutos del barrio.
  TravelTime get estimatedArrival => departure.shifted(zone.minutes);

  String get direction => toCampus ? 'to_campus' : 'from_campus';
}

/// Abre la hoja de publicación y devuelve el borrador, o `null` si se cerró.
///
/// ```dart
/// final draft = await showPublishRouteSheet(
///   context: context,
///   driverName: account.name,
///   driverInitials: initialsOf(account.name),
/// );
/// ```
Future<DraftRoute?> showPublishRouteSheet({
  required BuildContext context,
  required String driverName,
  required String driverInitials,
}) {
  return showModalBottomSheet<DraftRoute>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    showDragHandle: false,
    backgroundColor: context.palette.surface,
    barrierColor: const Color(0x8C0A0820),
    constraints: const BoxConstraints(maxWidth: 640),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.91,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      builder: (context, scrollController) => _PublishSheet(
        driverName: driverName,
        driverInitials: driverInitials,
        scrollController: scrollController,
      ),
    ),
  );
}

class _PublishSheet extends StatefulWidget {
  const _PublishSheet({
    required this.driverName,
    required this.driverInitials,
    required this.scrollController,
  });

  final String driverName;
  final String driverInitials;
  final ScrollController scrollController;

  @override
  State<_PublishSheet> createState() => _PublishSheetState();
}

class _PublishSheetState extends State<_PublishSheet> {
  late final DraftRoute _draft = DraftRoute(
    driverName: widget.driverName,
    driverInitials: widget.driverInitials,
  );
  final TextEditingController _meetingPoint = TextEditingController();

  @override
  void dispose() {
    _meetingPoint.dispose();
    super.dispose();
  }

  Zone _resolveZone(SelectedLocation location) {
    final direct = Zones.byName(location.addressText);
    if (direct != null && !direct.isCampus) return direct;

    final lower = location.addressText.toLowerCase();
    for (final zone in Zones.neighborhoods) {
      if (lower.contains(zone.name.toLowerCase())) {
        return zone;
      }
    }

    Zone best = Zones.neighborhoods.first;
    double minDistance = double.infinity;
    for (final zone in Zones.neighborhoods) {
      final dLat = zone.latitude - location.lat;
      final dLng = zone.longitude - location.lng;
      final d2 = dLat * dLat + dLng * dLng;
      if (d2 < minDistance) {
        minDistance = d2;
        best = zone;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    return RoutbSheetScaffold(
      title: 'Nueva ruta',
      scrollController: widget.scrollController,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Sentido y Horario
          const SectionLabel(title: 'Trayecto y horario'),
          RoutbSegmented<bool>(
            options: const <({bool value, String label})>[
              (value: true, label: 'Voy a la UTB'),
              (value: false, label: 'Salgo de la UTB'),
            ],
            value: _draft.toCampus,
            onChanged: (value) => setState(() => _draft.toCampus = value),
          ),
          const SizedBox(height: 12),
          DateQuickPicker(
            value: _draft.departureDate,
            onChanged: (date) => setState(() => _draft.departureDate = date),
          ),
          const SizedBox(height: 12),
          DepartureStepper(
            departure: _draft.departure,
            onChanged: (value) => setState(() => _draft.departure = value),
          ),

          const SizedBox(height: 20),
          // 2. Ubicación en Cartagena (búsqueda, barrios, GPS y mapa)
          SectionLabel(
            title: _draft.toCampus
                ? 'Punto de salida en Cartagena'
                : 'Punto de llegada en Cartagena',
            trailing: _draft.driverPoint != null
                ? _draft.zone.name
                : 'Obligatorio',
          ),
          AddressSearchField(
            toCampus: _draft.toCampus,
            label: _draft.toCampus
                ? 'Escribe tu dirección o barrio de salida'
                : 'Escribe tu dirección o barrio de llegada',
            initialLocation: _draft.driverPoint,
            onLocationSelected: (location) {
              setState(() {
                _draft.driverPoint = location;
                _draft.zone = _resolveZone(location);
              });
            },
            onLocationCleared: () => setState(() => _draft.driverPoint = null),
          ),

          const SizedBox(height: 20),
          // 3. Cupos y Punto de encuentro
          SectionLabel(
            title: 'Cupos disponibles',
            trailing: _draft.seats == 1 ? '1 cupo' : '${_draft.seats} cupos',
          ),
          Center(
            child: SeatPicker(
              seats: _draft.seats,
              onChanged: (value) => setState(() => _draft.seats = value),
            ),
          ),

          if (!_draft.toCampus) ...[
            const SizedBox(height: 20),
            const SectionLabel(title: 'Punto de encuentro en UTB'),
            RoutbField(
              hint: 'Ej. Portería principal / Bahía de buses UTB',
              icon: Icons.flag_outlined,
              controller: _meetingPoint,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (value) {
                setState(() => _draft.meetingPoint = value);
              },
            ),
          ],

          const RoutbHint(
            'El trayecto se calcula y publica con base en el barrio y las paradas.',
            margin: EdgeInsets.only(top: 18),
          ),
        ],
      ),
      footer: RoutbButton(
        label: 'Publicar ruta',
        onPressed:
            ((!_draft.toCampus && _draft.meetingPoint.trim().length < 3) ||
                _draft.driverPoint == null)
            ? null
            : () {
                if (_draft.toCampus && _draft.meetingPoint.trim().isEmpty) {
                  _draft.meetingPoint = 'Por coordinar';
                }
                Navigator.of(context).pop(_draft);
              },
      ),
    );
  }
}

/// `.cs` con `SeatSlots`: selector de cupos ofrecidos.
class SeatPicker extends StatelessWidget {
  const SeatPicker({required this.seats, required this.onChanged, super.key});

  final int seats;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) =>
      SeatSlots(selected: seats, onChanged: onChanged, maxSeats: 4);
}

/// Selector de hora de salida práctico e interactivo (B-8) sin leyenda artificial (B-7).
class DepartureStepper extends StatelessWidget {
  const DepartureStepper({
    required this.departure,
    required this.onChanged,
    this.zoneMinutes,
    super.key,
  });

  /// Hora actual del formulario.
  final TravelTime departure;

  /// Minutos opcionales por compatibilidad.
  final int? zoneMinutes;

  /// Se dispara con la hora ya ajustada.
  final ValueChanged<TravelTime> onChanged;

  static const int stepMinutes = 15;

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: departure.hour, minute: departure.minute),
      helpText: 'Selecciona la hora de salida',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (picked != null) {
      onChanged(TravelTime.fromClock(picked.hour, picked.minute));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.line, width: 1),
      ),
      child: Row(
        children: [
          _StepButton(
            label: '−15',
            semanticLabel: '15 minutos antes',
            onTap: () => onChanged(departure.shifted(-stepMinutes)),
          ),
          Expanded(
            child: InkWell(
              onTap: () => _pickTime(context),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 20,
                          color: palette.brand,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          departure.label,
                          style: RoutbText.headline(
                            28,
                            color: palette.ink,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Toca para cambiar la hora',
                      style: RoutbText.copy(
                        11,
                        color: palette.muted,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _StepButton(
            label: '+15',
            semanticLabel: '15 minutos después',
            onTap: () => onChanged(departure.shifted(stepMinutes)),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.label,
    required this.semanticLabel,
    required this.onTap,
  });

  final String label;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Text(
                label,
                style: RoutbText.headline(22, color: palette.brand),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.lb`: etiqueta de sección con texto atenuado a la derecha.
class SectionLabel extends StatelessWidget {
  const SectionLabel({required this.title, this.trailing, super.key});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: RoutbText.headline(14, color: palette.ink),
            ),
          ),
          if (trailing != null)
            Text(trailing!, style: RoutbText.copy(12, color: palette.muted)),
        ],
      ),
    );
  }
}
