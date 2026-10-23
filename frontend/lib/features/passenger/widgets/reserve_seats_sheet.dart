import 'package:flutter/material.dart';

import '../../../app/dependencies.dart';
import '../../../core/constants/zones.dart';
import '../../../core/models/trip.dart';
import '../../../core/models/trip_request.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/routb_palette.dart';
import '../../../core/theme/routb_text.dart';
import '../../../core/widgets/address_search_field.dart';
import '../../../core/widgets/routb_button.dart';
import '../../../core/widgets/routb_seats.dart';
import '../../../core/widgets/routb_sheet.dart';
import '../../../core/widgets/routb_toast.dart';
import '../../trips/data/trip_repository.dart';

/// Mini pantalla de solicitud de cupos simplificada (B-1).
///
/// Si el viaje va a la UTB, el destino ya es conocido (UTB) y solo se pide
/// el punto de recogida. Si el viaje sale de la UTB, el origen ya es conocido
/// (UTB) y solo se pide el punto de bajada.
///
/// La hora de salida se toma de la ruta seleccionada y no se pregunta aquí.
/// La solicitud se despacha directamente al conductor desde esta hoja.
Future<ReserveSeatsResult?> showReserveSeatsSheet({
  required BuildContext context,
  required Trip trip,
}) {
  return showModalBottomSheet<ReserveSeatsResult>(
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
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      builder: (context, scrollController) =>
          _ReserveSeatsSheet(trip: trip, scrollController: scrollController),
    ),
  );
}

/// Respuesta de la mini pantalla: cupos, paradas y solicitud creada.
class ReserveSeatsResult {
  const ReserveSeatsResult({
    required this.seatCount,
    required this.stops,
    this.request,
  });

  /// Cupos pedidos, de 1 a 4.
  final int seatCount;

  /// Paradas a enviar.
  final List<RequestStopInput> stops;

  /// Solicitud ya despachada y creada en el servidor, si aplica.
  final TripRequest? request;
}

class _ReserveSeatsSheet extends StatefulWidget {
  const _ReserveSeatsSheet({
    required this.trip,
    required this.scrollController,
  });

  final Trip trip;
  final ScrollController scrollController;

  @override
  State<_ReserveSeatsSheet> createState() => _ReserveSeatsSheetState();
}

class _ReserveSeatsSheetState extends State<_ReserveSeatsSheet> {
  int _seatCount = 1;
  SelectedLocation? _location;
  String _placeType = 'door';
  bool _submitting = false;

  Trip get _trip => widget.trip;

  /// Determina si el viaje va hacia el campus o sale de él.
  bool get _toCampus {
    if (_trip.direction == 'to_campus') return true;
    if (_trip.direction == 'from_campus') return false;
    return _trip.destination.toLowerCase().contains('utb') ||
        Zones.byName(_trip.destination)?.isCampus == true;
  }

  /// El backend acepta de 1 a 4 cupos y solo los que queden libres.
  int get _maximum => _trip.availableSeats.clamp(1, 4).toInt();

  /// El texto se normaliza para asegurar un `address_text` válido.
  String get _addressText {
    final text = _location?.addressText.trim() ?? '';
    if (text.isNotEmpty) return text;
    return _toCampus ? 'Punto de recogida' : 'Punto de bajada';
  }

  String get _driverFirstName =>
      _trip.hasDriverName ? _trip.driverName!.split(' ').first : 'el conductor';

  List<RequestStopInput> get _stops => _location != null
      ? <RequestStopInput>[
          RequestStopInput(
            seats: _seatCount,
            placeType: _placeType,
            location: SelectedLocation(
              lat: _location!.lat,
              lng: _location!.lng,
              addressText: _addressText,
            ),
          ),
        ]
      : const <RequestStopInput>[];

  bool get _canConfirm => _location != null && !_submitting;

  Future<void> _submit() async {
    if (!_canConfirm) return;
    setState(() => _submitting = true);

    try {
      final repository = RoutbScopeDependencies.of(context).trips;
      final created = await repository.requestSeat(
        _trip.id,
        seatCount: _seatCount,
        stops: _stops,
      );
      if (!mounted) return;
      Navigator.of(context).pop(
        ReserveSeatsResult(
          seatCount: _seatCount,
          stops: _stops,
          request: created,
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      RoutbToast.show(context, error.message);
    } on Exception catch (error) {
      if (!mounted) return;
      RoutbToast.show(context, 'No se pudo enviar la solicitud: $error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return RoutbSheetScaffold(
      title: _toCampus
          ? 'Solicitar cupo hacia la UTB'
          : 'Solicitar cupo desde la UTB',
      subtitle: _toCampus
          ? 'Destino fijo: UTB Campus Tecnológico'
          : 'Salida fija: UTB · ${_trip.meetingPoint}',
      scrollController: widget.scrollController,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tarjeta contextual con información del viaje (no editable aquí)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.line),
            ),
            child: Row(
              children: [
                InitialsAvatar(
                  name: _trip.driverName ?? 'Conductor',
                  initials: _trip.driverInitials,
                  size: 38,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _trip.driverName ?? 'Conductor ROUTB',
                        style: RoutbText.headline(14, color: palette.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Salida ${_trip.departureLabel} · ${_trip.departureDateLabel}',
                        style: RoutbText.copy(12, color: palette.muted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: palette.brandSurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _toCampus ? 'Hacia UTB' : 'Desde UTB',
                    style: RoutbText.copy(
                      11,
                      color: palette.onBrandSurface,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Selector de cupos
          _SectionLabel(
            title: '¿Cuántos cupos necesitas?',
            trailing: _seatCount == 1 ? '1 cupo' : '$_seatCount cupos',
          ),
          Center(
            child: SeatSlots(
              selected: _seatCount,
              maxSeats: _maximum,
              onChanged: _submitting
                  ? null
                  : (value) => setState(() => _seatCount = value),
            ),
          ),
          const SizedBox(height: 20),

          // Pregunta única de ubicación según el sentido
          _SectionLabel(
            title: _toCampus ? '¿Dónde te recogemos?' : '¿Dónde te bajamos?',
            trailing: 'Obligatorio',
          ),
          AddressSearchField(
            toCampus: _toCampus,
            label: _toCampus
                ? 'Escribe tu dirección o barrio de recogida'
                : 'Escribe tu dirección o barrio de bajada',
            onLocationSelected: (location) =>
                setState(() => _location = location),
            onLocationCleared: () => setState(() => _location = null),
          ),
          const SizedBox(height: 18),

          // Tipo de punto (en la puerta / punto de encuentro)
          const _SectionLabel(title: 'Tipo de punto'),
          RoutbSegmented<String>(
            options: const <({String value, String label})>[
              (value: 'door', label: 'En la puerta'),
              (value: 'meeting_point', label: 'Punto de encuentro'),
            ],
            value: _placeType,
            onChanged: (value) {
              if (!_submitting) setState(() => _placeType = value);
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
      footer: RoutbButton(
        label: _seatCount == 1
            ? 'Enviar solicitud a $_driverFirstName (1 cupo)'
            : 'Enviar solicitud a $_driverFirstName ($_seatCount cupos)',
        icon: Icons.send_rounded,
        busy: _submitting,
        onPressed: _canConfirm ? _submit : null,
      ),
    );
  }
}

/// Etiqueta de sección con el valor a la derecha.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
