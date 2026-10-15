import 'package:flutter/material.dart';

import '../../../app/dependencies.dart';
import '../../../core/models/trip.dart';
import '../../../core/theme/routb_palette.dart';
import '../../../core/theme/routb_text.dart';
import '../../../core/widgets/address_search_field.dart';
import '../../../core/widgets/routb_button.dart';
import '../../../core/widgets/routb_seats.dart';
import '../../../core/widgets/routb_sheet.dart';
import '../../trips/data/trip_repository.dart';

/// Mini pantalla de solicitud de cupos.
///
/// El pasajero ya eligió el viaje en el listado, así que aquí solo se le pide
/// **cuántos cupos** quiere. Si el viaje tiene `direction` se pide además el
/// **punto** (recogida o bajada), porque `create_request` rechaza con una
/// excepción las solicitudes sin paradas en los viajes con sentido: sin este
/// campo la petición volvería 500 y el cupo no se pediría.
///
/// Una sola parada satisface los dos sentidos: `to_campus` exige exactamente
/// una y `from_campus` admite hasta una por pasajero con `seats` igual al total.
///
/// ```dart
/// final choice = await showReserveSeatsSheet(context: context, trip: trip);
/// if (choice == null) return;
/// ```
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
      // Con parada el formulario es más alto: se abre más lleno para que el
      // campo de dirección no quede bajo el pliegue.
      initialChildSize: trip.direction == null ? 0.55 : 0.82,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      builder: (context, scrollController) =>
          _ReserveSeatsSheet(trip: trip, scrollController: scrollController),
    ),
  );
}

/// Respuesta de la mini pantalla: cuántos cupos y con qué paradas enviar.
class ReserveSeatsResult {
  const ReserveSeatsResult({required this.seatCount, required this.stops});

  /// Cupos pedidos, de 1 a 4.
  final int seatCount;

  /// Paradas a enviar; vacías en los viajes legados sin `direction`.
  final List<RequestStopInput> stops;
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

  Trip get _trip => widget.trip;

  /// Los viajes con sentido exigen una parada; los legados, ninguna.
  bool get _needsStop => _trip.direction != null;

  bool get _toCampus => _trip.direction == 'to_campus';

  /// El backend acepta de 1 a 4 cupos y solo los que queden libres.
  int get _maximum => _trip.availableSeats.clamp(1, 4).toInt();

  /// El texto se normaliza porque arrastrar el mapa sin buscar deja la
  /// dirección vacía, y `address_text` no puede llegar en blanco.
  String get _addressText {
    final text = _location?.addressText.trim() ?? '';
    if (text.isNotEmpty) return text;
    return _toCampus ? 'Punto de recogida' : 'Punto de bajada';
  }

  ReserveSeatsResult get _result => ReserveSeatsResult(
    seatCount: _seatCount,
    stops: _needsStop && _location != null
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
        : const <RequestStopInput>[],
  );

  @override
  Widget build(BuildContext context) {
    final canConfirm = !_needsStop || _location != null;

    return RoutbSheetScaffold(
      title: 'Solicitar cupos',
      subtitle: '${_trip.origin} → ${_trip.destination}',
      scrollController: widget.scrollController,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(
            title: '¿Cuántos cupos necesitas?',
            trailing: _seatCount == 1 ? '1 cupo' : '$_seatCount cupos',
          ),
          Center(
            child: SeatSlots(
              selected: _seatCount,
              maxSeats: _maximum,
              onChanged: (value) => setState(() => _seatCount = value),
            ),
          ),
          if (_needsStop) ...[
            const SizedBox(height: 18),
            _SectionLabel(
              title: _toCampus ? '¿Dónde te recogemos?' : '¿Dónde te bajamos?',
              trailing: 'Obligatorio',
            ),
            AddressSearchField(
              geocodeRepository: RoutbScopeDependencies.of(context).geocode,
              label: _toCampus
                  ? 'Busca tu punto de recogida'
                  : 'Busca tu punto de bajada',
              onLocationSelected: (location) =>
                  setState(() => _location = location),
              onLocationCleared: () => setState(() => _location = null),
            ),
            const SizedBox(height: 18),
            const _SectionLabel(title: 'Tipo de punto'),
            RoutbSegmented<String>(
              options: const <({String value, String label})>[
                (value: 'door', label: 'En la puerta'),
                (value: 'meeting_point', label: 'Punto de encuentro'),
              ],
              value: _placeType,
              onChanged: (value) => setState(() => _placeType = value),
            ),
          ],
        ],
      ),
      footer: RoutbButton(
        label: _seatCount == 1
            ? 'Solicitar 1 cupo'
            : 'Solicitar $_seatCount cupos',
        onPressed: canConfirm ? () => Navigator.of(context).pop(_result) : null,
      ),
    );
  }
}

/// Etiqueta de sección con el valor a la derecha, igual que en la hoja de
/// publicación de rutas.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, this.trailing});

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
