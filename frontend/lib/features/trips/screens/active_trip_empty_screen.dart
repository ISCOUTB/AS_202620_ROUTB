import 'package:flutter/material.dart';

import '../../../core/models/user_role.dart';
import '../../../core/theme/routb_palette.dart';
import '../../../core/theme/routb_text.dart';
import '../../../core/theme/routb_theme.dart';
import '../../../core/widgets/routb_button.dart';

/// Atajo que ofrece el estado vacío del viaje activo.
enum ActiveTripShortcut { search, publish }

/// Estado vacío del botón central cuando no hay viaje activo.
///
/// No es una pestaña: se abre encima de la pantalla actual y devuelve el atajo
/// que la persona eligió para que la pantalla de origen cambie de pestaña o
/// abra el formulario de publicación.
class ActiveTripEmptyScreen extends StatelessWidget {
  const ActiveTripEmptyScreen({required this.role, super.key});

  /// Rol que determina el texto y el atajo.
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final passenger = role == UserRole.passenger;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(title: const Text('Viaje activo')),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: RoutbTheme.contentMaxWidth,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
              children: [
                Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: palette.brandSurface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      passenger
                          ? Icons.directions_car_outlined
                          : Icons.route_outlined,
                      size: 34,
                      color: palette.brand,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  passenger
                      ? 'No tienes un viaje activo'
                      : 'No tienes una ruta activa',
                  textAlign: TextAlign.center,
                  style: RoutbText.headline(22, color: palette.ink),
                ),
                const SizedBox(height: 8),
                Text(
                  passenger
                      ? 'Cuando solicites un cupo o te confirmen uno, podrás '
                            'seguir el viaje desde aquí.'
                      : 'Publica una ruta para que los pasajeros te encuentren y '
                            'puedas responder sus solicitudes. Si tu última ruta '
                            'ya salió, la encuentras en el historial.',
                  textAlign: TextAlign.center,
                  style: RoutbText.copy(13, color: palette.muted, height: 1.45),
                ),
                const SizedBox(height: 24),
                RoutbButton(
                  label: passenger ? 'Ir a Viajes' : 'Publicar ruta',
                  icon: passenger
                      ? Icons.search_rounded
                      : Icons.add_road_rounded,
                  onPressed: () => Navigator.of(context).pop(
                    passenger
                        ? ActiveTripShortcut.search
                        : ActiveTripShortcut.publish,
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Volver', style: TextStyle(color: palette.muted)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
