import 'package:flutter/material.dart';

import '../theme/routb_motion.dart';
import '../theme/routb_palette.dart';
import '../theme/routb_text.dart';

/// Muestra avisos flotantes con la estética de `.toast`.
///
/// El aviso es oscuro, con el color de fondo del tema invertido, y ocupa el
/// ancho de la pantalla con un margen lateral. Vive sobre el contenido, sin
/// barra de estado ni botón de cierre.
///
/// ```dart
/// RoutbToast.show(context, 'Ruta publicada. Ya la ven los pasajeros');
/// ```
abstract final class RoutbToast {
  /// Muestra [message] durante [duration].
  static void show(
    BuildContext context,
    String message, {
    Duration duration = RoutbMotion.toastVisible,
  }) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _RoutbToastEntry(
        message: message,
        duration: duration,
        onDismissed: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );
    overlay.insert(entry);
  }
}

class _RoutbToastEntry extends StatefulWidget {
  const _RoutbToastEntry({
    required this.message,
    required this.duration,
    required this.onDismissed,
  });

  final String message;
  final Duration duration;
  final VoidCallback onDismissed;

  @override
  State<_RoutbToastEntry> createState() => _RoutbToastEntryState();
}

class _RoutbToastEntryState extends State<_RoutbToastEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: RoutbMotion.toast,
    reverseDuration: RoutbMotion.toast,
  );

  bool _shown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // La preferencia de movimiento se lee aquí: `initState` todavía no puede
    // consultar `MediaQuery`.
    if (_shown) return;
    _shown = true;
    _show();
  }

  @override
  void initState() {
    super.initState();

    Future<void>.delayed(widget.duration, () async {
      if (!mounted) return;
      await _controller.reverse();
      widget.onDismissed();
    });
  }

  void _show() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      return;
    }
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Positioned(
      left: 16,
      right: 16,
      bottom: 84,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _controller,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.1),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: _controller, curve: Curves.easeOut),
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Semantics(
                liveRegion: true,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: palette.ink,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      widget.message,
                      style: RoutbText.copy(
                        13,
                        color: palette.background,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}