import 'package:flutter/material.dart';

import '../../../core/models/my_request.dart';
import '../../../core/theme/routb_palette.dart';
import '../../../core/theme/routb_text.dart';
import '../../../core/theme/routb_theme.dart';
import '../widgets/my_trip_card.dart';

/// Lista de viajes activos cuando el pasajero tiene más de uno.
///
/// El botón central abre directamente el detalle cuando solo hay uno; con dos
/// o más, esta pantalla evita tener que elegir a ciegas. Al abrir un detalle y
/// volver, la lista se cierra para que el pasajero regrese a la pestaña desde
/// la que pulsó el centro.
class ActiveTripsScreen extends StatelessWidget {
  const ActiveTripsScreen({
    required this.requests,
    required this.onOpen,
    this.lastUpdated,
    super.key,
  });

  /// Solicitudes activas, ya ordenadas por prioridad.
  final List<MyRequest> requests;

  /// Abre el detalle de una solicitud. La pantalla espera a que se cierre para
  /// volver a la pantalla de origen.
  final Future<void> Function(MyRequest request) onOpen;

  /// Momento del último sondeo, para la etiqueta de frescura.
  final DateTime? lastUpdated;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(title: const Text('Viajes activos')),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: RoutbTheme.contentMaxWidth,
            ),
            child: ListView(
              key: const PageStorageKey<String>('active-trips'),
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
              children: [
                Text(
                  requests.length == 1
                      ? 'Tienes un viaje activo.'
                      : 'Tienes ${requests.length} viajes activos.',
                  style: RoutbText.headline(20, color: palette.ink),
                ),
                const SizedBox(height: 6),
                Text(
                  'Elige uno para ver el detalle, el conductor y el punto de '
                  'encuentro.',
                  style: RoutbText.copy(13, color: palette.muted, height: 1.4),
                ),
                const SizedBox(height: 14),
                for (final request in requests) ...[
                  MyTripCard(
                    request: request,
                    lastUpdated: lastUpdated,
                    onTap: () async {
                      await onOpen(request);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
