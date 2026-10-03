import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/routb_motion.dart';
import '../theme/routb_palette.dart';

/// `true` cuando el sistema pide reducir el movimiento.
///
/// Todo lo que se anima en ROUTB consulta esta bandera a través de
/// [RoutbAnimations.enabled] y se muestra ya en su estado final.
bool animationsEnabled(BuildContext context) =>
    !MediaQuery.disableAnimationsOf(context);

/// Entrada escalonada de las tarjetas.
///
/// El diseño anima cada tarjeta con `animation-delay: index * 90ms`. [index] es
/// la posición de la tarjeta dentro de su lista.
///
/// Con movimiento reducido el hijo se muestra directamente, sin animación.
class RoutbEntrance extends StatefulWidget {
  const RoutbEntrance({
    required this.index,
    required this.child,
    this.verticalOffset = 14,
    super.key,
  });

  /// Posición de la tarjeta en la lista, desde cero.
  final int index;

  /// Contenido que entra.
  final Widget child;

  /// Desplazamiento vertical en píxeles lógicos antes de entrar.
  final double verticalOffset;

  @override
  State<RoutbEntrance> createState() => _RoutbEntranceState();
}

class _RoutbEntranceState extends State<RoutbEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: RoutbMotion.enter,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // La preferencia de movimiento se lee aquí porque `initState` no puede
    // consultar `InheritedWidget`.
    if (!animationsEnabled(context)) {
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
    if (!animationsEnabled(context)) return widget.child;

    final delay = RoutbMotion.stagger * widget.index;
    if (delay > Duration.zero) {
      return _DelayedStart(
        delay: delay,
        controller: _controller,
        builder: (context) => _buildAnimated(),
      );
    }
    return _buildAnimated();
  }

  Widget _buildAnimated() {
    final curved = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, widget.verticalOffset),
          end: Offset.zero,
        ).animate(curved),
        child: widget.child,
      ),
    );
  }
}

/// Aplaza el arranque de una animación sin.timer propio.
class _DelayedStart extends StatefulWidget {
  const _DelayedStart({
    required this.delay,
    required this.controller,
    required this.builder,
  });

  final Duration delay;
  final AnimationController controller;
  final WidgetBuilder builder;

  @override
  State<_DelayedStart> createState() => _DelayedStartState();
}

class _DelayedStartState extends State<_DelayedStart> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (!mounted) return;
      setState(() => _ready = true);
      widget.controller.forward();
    });
  }

  @override
  Widget build(BuildContext context) =>
      _ready ? widget.builder(context) : const SizedBox.shrink();
}

/// Réplica de `:active { transform: scale(.86) }`.
///
/// Aporta además lo que el CSS no cubre: se puede activar con teclado
/// (Enter y espacio) y dibuja el anillo de foco menta cuando recibe el foco.
class Pressable extends StatefulWidget {
  const Pressable({
    required this.child,
    this.onTap,
    this.scale = RoutbMotion.pressScale,
    this.semanticLabel,
    this.button = true,
    this.enabled = true,
    this.borderRadius,
    this.focusNode,
    super.key,
  });

  /// Contenido que se escala.
  final Widget child;

  /// Acción al pulsar. Si es `null` el control queda inactivo.
  final VoidCallback? onTap;

  /// Factor de escala al pulsar.
  final double scale;

  /// Etiqueta que anuncia el lector de pantalla.
  final String? semanticLabel;

  /// `true` para que el lector de pantalla lo anuncie como botón.
  final bool button;

  /// `false` para atenuarlo sin quitarlo de la pantalla.
  final bool enabled;

  /// Radio con el que se dibuja el anillo de foco.
  final BorderRadius? borderRadius;

  /// Nodo de foco externo, para mover el foco desde el código.
  final FocusNode? focusNode;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
    reverseDuration: const Duration(milliseconds: 120),
  );

  bool _focused = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _press() {
    if (widget.onTap == null || !widget.enabled) return;
    if (animationsEnabled(context)) _controller.forward();
  }

  void _release() {
    if (animationsEnabled(context)) _controller.reverse();
  }

  void _activate() {
    final onTap = widget.onTap;
    if (onTap == null || !widget.enabled) return;
    onTap();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final isActivation =
        event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.space ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter;
    if (!isActivation) return KeyEventResult.ignored;

    _press();
    _release();
    _activate();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = widget.borderRadius ?? BorderRadius.circular(14);
    final interactive = widget.onTap != null && widget.enabled;

    Widget content = widget.child;

    if (_focused) {
      content = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: palette.mint, width: 2),
        ),
        child: content,
      );
    }

    final scale = Tween<double>(begin: 1, end: widget.scale).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    return Semantics(
      button: widget.button,
      enabled: widget.enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: interactive ? _activate : null,
        onTapDown: interactive ? (_) => _press() : null,
        onTapUp: interactive ? (_) => _release() : null,
        onTapCancel: interactive ? _release : null,
        child: Focus(
          focusNode: widget.focusNode,
          canRequestFocus: interactive,
          onFocusChange: (value) => setState(() => _focused = value),
          onKeyEvent: _onKey,
          child: AnimatedBuilder(
            animation: scale,
            builder: (context, child) => Transform.scale(
              scale: scale.value,
              child: child,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// Punto que late, como el indicador de disponibilidad del mapa.
class PulsingDot extends StatefulWidget {
  const PulsingDot({
    required this.color,
    this.size = 7,
    super.key,
  });

  /// Color del punto y de su halo.
  final Color color;

  /// Diámetro en píxeles lógicos.
  final double size;

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: RoutbMotion.pulse,
  );

  bool _pulsing = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pulsing = animationsEnabled(context);
    if (_pulsing) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.size;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => CustomPaint(
          size: Size.square(base * 3),
          painter: _PulsePainter(
            progress: _controller.value,
            color: widget.color,
            radius: base / 2,
            pulses: _pulsing,
          ),
        ),
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  const _PulsePainter({
    required this.progress,
    required this.color,
    required this.radius,
    required this.pulses,
  });

  final double progress;
  final Color color;
  final double radius;

  /// `false` cuando el sistema pide reducir el movimiento: se pinta solo el
  /// punto, sin halo que se expande.
  final bool pulses;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    if (pulses) {
      final halo = (1 - progress).clamp(0.0, 1.0);
      if (halo > 0) {
        canvas.drawCircle(
          center,
          radius + (maxRadius - radius) * progress,
          Paint()..color = color.withValues(alpha: 0.55 * halo),
        );
      }
    }
    canvas.drawCircle(center, radius, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PulsePainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.radius != radius ||
      old.pulses != pulses;
}