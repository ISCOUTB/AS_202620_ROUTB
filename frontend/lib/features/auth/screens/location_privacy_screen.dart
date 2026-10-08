import 'package:flutter/material.dart';

import '../../../app/dependencies.dart';
import '../../../core/theme/routb_palette.dart';
import '../../../core/widgets/routb_button.dart';

/// Ajustes de autorización para el uso de ubicaciones exactas.
class LocationPrivacyScreen extends StatefulWidget {
  const LocationPrivacyScreen({super.key});

  @override
  State<LocationPrivacyScreen> createState() => _LocationPrivacyScreenState();
}

class _LocationPrivacyScreenState extends State<LocationPrivacyScreen> {
  bool _revoking = false;
  String? _message;

  Future<void> _revoke() async {
    setState(() {
      _revoking = true;
      _message = null;
    });
    try {
      await RoutbScopeDependencies.of(context).auth.revokeLocationConsent();
      if (!mounted) return;
      setState(() {
        _revoking = false;
        _message = 'Autorización revocada. Se cancelaron tus solicitudes pendientes y se borraron sus ubicaciones.';
      });
    } on Exception {
      if (!mounted) return;
      setState(() {
        _revoking = false;
        _message = 'No se pudo revocar ahora. Revisa tu conexión e inténtalo de nuevo.';
      });
    }
  }

  Future<void> _grant() async {
    setState(() {
      _revoking = true;
      _message = null;
    });
    try {
      await RoutbScopeDependencies.of(context).auth.grantLocationConsent();
      if (!mounted) return;
      setState(() {
        _revoking = false;
        _message = 'Autorización registrada. Ya puedes usar las funciones que requieren ubicación.';
      });
    } on Exception {
      if (!mounted) return;
      setState(() {
        _revoking = false;
        _message = 'No se pudo registrar la autorización. Revisa tu conexión e inténtalo de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text('Privacidad de ubicación')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Puedes revocar esta autorización cuando quieras. Al hacerlo, se cancelan tus solicitudes pendientes y se eliminan las ubicaciones asociadas.',
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: palette.ink),
            ),
            const SizedBox(height: 12),
            Text(
              'Después de revocarla, no podrás buscar direcciones ni publicar o solicitar viajes que necesiten coordenadas exactas. Los viajes y solicitudes que no usan ubicación seguirán disponibles.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: palette.muted),
            ),
            const SizedBox(height: 24),
            RoutbButton(
              label: _revoking ? 'Guardando…' : 'Revocar autorización',
              onPressed: _revoking ? null : _revoke,
            ),
            TextButton(
              onPressed: _revoking ? null : _grant,
              child: const Text('Autorizar nuevamente'),
            ),
            if (_message != null) ...[
              const SizedBox(height: 16),
              Text(_message!, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}
