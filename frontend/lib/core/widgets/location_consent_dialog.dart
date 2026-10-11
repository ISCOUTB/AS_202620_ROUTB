import 'package:flutter/material.dart';

import '../theme/routb_palette.dart';
import 'routb_button.dart';

/// Diálogo explicativo de tratamiento de ubicación geográfica.
///
/// Informa qué datos se recolectan, su finalidad, período de retención
/// (30 días para viajes y 7 días para caché) y su carácter revocable,
/// cumpliendo con la Ley 1581 de 2012.
class LocationConsentDialog extends StatelessWidget {
  const LocationConsentDialog({super.key});

  /// Muestra el modal de consentimiento y retorna `true` si el usuario aceptó.
  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const LocationConsentDialog(),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: palette.surface,
      title: Row(
        children: [
          Icon(Icons.location_on_outlined, color: palette.brand),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Uso de tu ubicación',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: palette.ink,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Para sugerirte rutas y calcular puntos de encuentro precisos hacia y desde la UTB, ROUTB necesita recopilar tus coordenadas geográficas.',
              style: textTheme.bodyMedium?.copyWith(color: palette.ink),
            ),
            const SizedBox(height: 12),
            _BulletPoint(
              icon: Icons.shield_outlined,
              text: 'Privacidad protegida: el conductor solo ve tu dirección o barrio antes de aceptar.',
              palette: palette,
              textTheme: textTheme,
            ),
            const SizedBox(height: 8),
            _BulletPoint(
              icon: Icons.timer_outlined,
              text: 'Retención máxima de 30 días tras completarse el viaje con purga periódica automática.',
              palette: palette,
              textTheme: textTheme,
            ),
            const SizedBox(height: 8),
            _BulletPoint(
              icon: Icons.block_outlined,
              text: 'Puedes revocar esta autorización en cualquier momento desde tu perfil.',
              palette: palette,
              textTheme: textTheme,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Ahora no',
            style: textTheme.labelLarge?.copyWith(color: palette.muted),
          ),
        ),
        RoutbButton(
          label: 'Autorizar',
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}

class _BulletPoint extends StatelessWidget {
  const _BulletPoint({
    required this.icon,
    required this.text,
    required this.palette,
    required this.textTheme,
  });

  final IconData icon;
  final String text;
  final RoutbPalette palette;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: palette.brand),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: textTheme.bodySmall?.copyWith(color: palette.muted),
          ),
        ),
      ],
    );
  }
}
