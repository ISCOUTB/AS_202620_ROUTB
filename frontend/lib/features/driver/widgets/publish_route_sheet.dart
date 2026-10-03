import 'package:flutter/material.dart';

import '../../../core/constants/zones.dart';
import '../../../core/models/travel_time.dart';
import '../../../core/models/trip_schedule.dart';
import '../../../core/theme/routb_palette.dart';
import '../../../core/theme/routb_text.dart';
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

  /// Nombre del conductor, para la vista previa.
  final String driverName;

  /// Iniciales del conductor, para la vista previa.
  final String driverInitials;

  /// Barrio de partida.
  String get origin => toCampus ? zone.name : Zones.campus.name;

  /// Barrio de llegada.
  String get destination => toCampus ? Zones.campus.name : zone.name;

  /// Texto del trayecto, como lo muestra el conductor.
  String get routeLabel => '$origin → $destination';

  /// Llegada estimada según los minutos del barrio.
  TravelTime get estimatedArrival => departure.shifted(zone.minutes);
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
    builder: (sheetContext) =>
        _PublishSheet(driverName: driverName, driverInitials: driverInitials),
  );
}

class _PublishSheet extends StatefulWidget {
  const _PublishSheet({required this.driverName, required this.driverInitials});

  final String driverName;
  final String driverInitials;

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

  Future<void> _chooseDate() async {
    final today = TripSchedule.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _draft.departureDate.isBefore(today)
          ? today
          : _draft.departureDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 30)),
      helpText: '¿Qué día viajas?',
      cancelText: 'Cancelar',
      confirmText: 'Elegir día',
    );
    if (picked != null && mounted) {
      setState(() => _draft.departureDate = TripSchedule.dateOnly(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RoutbSheetScaffold(
      title: 'Nueva ruta',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel(title: 'Fecha del viaje'),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _chooseDate,
              icon: const Icon(Icons.calendar_today_rounded, size: 16),
              label: Text(TripSchedule.dateLabel(_draft.departureDate)),
            ),
          ),

          SectionLabel(
            title: 'Trayecto',
            trailing: _draft.toCampus ? 'Sales desde' : 'Llegas a',
          ),
          RoutbSegmented<bool>(
            options: const <({bool value, String label})>[
              (value: true, label: 'Voy a la UTB'),
              (value: false, label: 'Salgo de la UTB'),
            ],
            value: _draft.toCampus,
            onChanged: (value) => setState(() => _draft.toCampus = value),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final zone in Zones.neighborhoods)
                RoutbChip(
                  label: zone.name,
                  selected: zone.name == _draft.zone.name,
                  onTap: () => setState(() => _draft.zone = zone),
                ),
            ],
          ),

          const SizedBox(height: 22),
          const SectionLabel(title: 'Hora de salida'),
          DepartureStepper(
            departure: _draft.departure,
            zoneMinutes: _draft.zone.minutes,
            onChanged: (value) => setState(() => _draft.departure = value),
          ),

          const SizedBox(height: 22),
          SectionLabel(
            title: 'Cupos que ofreces',
            trailing: _draft.seats == 1 ? '1 cupo' : '${_draft.seats} cupos',
          ),
          Center(
            child: SeatPicker(
              seats: _draft.seats,
              onChanged: (value) => setState(() => _draft.seats = value),
            ),
          ),

          const SizedBox(height: 18),
          const SectionLabel(title: 'Punto de encuentro'),
          RoutbField(
            hint: 'Ej. Portería principal de la UTB',
            icon: Icons.place_outlined,
            controller: _meetingPoint,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (value) {
              setState(() => _draft.meetingPoint = value);
            },
          ),

          const RoutbHint(
            'El trayecto del mapa es una estimación entre los dos barrios: '
            'ROUTB no guarda rutas reales.',
            margin: EdgeInsets.only(top: 16),
          ),
        ],
      ),
      footer: RoutbButton(
        label: 'Publicar ruta',
        onPressed: _draft.meetingPoint.trim().length < 3
            ? null
            : () => Navigator.of(context).pop(_draft),
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

/// `.tm`: ajuste de la hora de salida en saltos de quince minutos.
class DepartureStepper extends StatelessWidget {
  const DepartureStepper({
    required this.departure,
    required this.zoneMinutes,
    required this.onChanged,
    super.key,
  });

  /// Hora actual del formulario.
  final TravelTime departure;

  /// Minutos del barrio, para estimar la llegada.
  final int zoneMinutes;

  /// Se dispara con la hora ya desplazada.
  final ValueChanged<TravelTime> onChanged;

  static const int stepMinutes = 15;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final arrival = departure.shifted(zoneMinutes);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _StepButton(
            label: '−',
            semanticLabel: 'Quince minutos antes',
            onTap: () => onChanged(departure.shifted(-stepMinutes)),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  departure.label,
                  style: RoutbText.headline(32, color: palette.ink, height: 1),
                ),
                const SizedBox(height: 3),
                Text(
                  'Llegas sobre las ${arrival.label}',
                  style: RoutbText.copy(12, color: palette.muted),
                ),
              ],
            ),
          ),
          _StepButton(
            label: '+',
            semanticLabel: 'Quince minutos después',
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
