import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Avisa que la ubicación está denegada y ofrece abrir los ajustes del sistema.
///
/// Se usa cuando una función concreta necesita el permiso (por ejemplo, el
/// botón «Usar mi ubicación» del buscador de direcciones). No se pide al
/// iniciar la app.
Future<void> showLocationPermissionDialog(BuildContext context) async {
  final openSettings = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Activa la ubicación'),
      content: const Text(
        'Para usar tu ubicación actual necesitas conceder el permiso de '
        'ubicación en los ajustes del celular. También puedes escribir tu '
        'dirección o elegir un barrio manualmente.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Ahora no'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Abrir ajustes'),
        ),
      ],
    ),
  );

  if (openSettings == true) {
    await Geolocator.openAppSettings();
  }
}
