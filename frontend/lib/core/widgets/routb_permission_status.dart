import 'package:flutter/material.dart';

import '../theme/routb_palette.dart';
import '../theme/routb_text.dart';
import 'routb_button.dart';
import 'routb_field.dart';

/// Estado de un permiso del sistema operativo que la app necesita.
enum RoutbPermissionState {
  /// Todavía se está consultando.
  loading,

  /// El permiso está concedido.
  granted,

  /// El permiso está denegado o el servicio está apagado.
  denied,
}

/// Fila reutilizable con el estado de un permiso y acceso a los ajustes.
///
/// Se usa en el Perfil para ubicación y notificaciones. No pide permisos por
/// sí sola: solo muestra el estado y ofrece abrir los ajustes del celular.
class RoutbPermissionStatus extends StatelessWidget {
  const RoutbPermissionStatus({
    required this.title,
    required this.description,
    required this.icon,
    required this.state,
    this.onOpenSettings,
    super.key,
  });

  /// Nombre del permiso («Ubicación», «Notificaciones»).
  final String title;

  /// Explicación breve de para qué se usa.
  final String description;

  /// Icono del permiso.
  final IconData icon;

  /// Estado actual.
  final RoutbPermissionState state;

  /// Acción para abrir los ajustes del sistema.
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final denied = state == RoutbPermissionState.denied;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: denied ? palette.amberSurface : palette.brandSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 19,
              color: denied ? palette.onAmberSurface : palette.brand,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: RoutbText.headline(14.5, color: palette.ink),
                      ),
                    ),
                    _statePill(palette),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: RoutbText.copy(12, color: palette.muted),
                ),
                if (denied && onOpenSettings != null) ...[
                  const SizedBox(height: 6),
                  RoutbTextAction(
                    label: 'Abrir ajustes',
                    icon: Icons.settings_outlined,
                    onPressed: onOpenSettings,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statePill(RoutbPalette palette) {
    return switch (state) {
      RoutbPermissionState.loading => const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      RoutbPermissionState.granted => RoutbStatusPill(
        label: 'Activo',
        background: palette.mintSurface,
        foreground: palette.onMintSurface,
      ),
      RoutbPermissionState.denied => RoutbStatusPill(
        label: 'Desactivado',
        background: palette.amberSurface,
        foreground: palette.onAmberSurface,
      ),
    };
  }
}
