import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/routb_palette.dart';
import '../theme/routb_text.dart';

/// Indicador de frescura de una consulta periódica.
///
/// Solo debe montarse mientras el sondeo esté activo. Al desaparecer el
/// sondeo, la pantalla deja de construir el widget y el temporizador se
/// cancela en [dispose].
class RoutbFreshnessLabel extends StatefulWidget {
  const RoutbFreshnessLabel({
    required this.lastUpdated,
    this.tick = const Duration(seconds: 5),
    super.key,
  });

  /// Momento de la última consulta exitosa.
  final DateTime lastUpdated;

  /// Cada cuánto se recalcula el texto visible.
  final Duration tick;

  @override
  State<RoutbFreshnessLabel> createState() => _RoutbFreshnessLabelState();
}

class _RoutbFreshnessLabelState extends State<RoutbFreshnessLabel> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.tick, (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final elapsed = DateTime.now().difference(widget.lastUpdated);
    final seconds = elapsed.inSeconds < 0 ? 0 : elapsed.inSeconds;
    final text = seconds < 5
        ? 'Actualizado ahora'
        : seconds < 60
        ? 'Actualizado hace $seconds s'
        : 'Actualizado hace ${elapsed.inMinutes} min';

    return Semantics(
      label: text,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sync_rounded, size: 12, color: palette.muted),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RoutbText.copy(11, color: palette.muted),
            ),
          ),
        ],
      ),
    );
  }
}
