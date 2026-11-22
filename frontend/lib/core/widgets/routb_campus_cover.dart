import 'dart:async';

import 'package:flutter/material.dart';

/// Rota solo el fondo de la cabecera. El título y las acciones quedan fijos.
class RoutbCampusCover extends StatefulWidget {
  const RoutbCampusCover({required this.child, super.key});
  final Widget child;

  @override
  State<RoutbCampusCover> createState() => _RoutbCampusCoverState();
}

class _RoutbCampusCoverState extends State<RoutbCampusCover>
    with WidgetsBindingObserver {
  static const scenes = [
    'cartagena',
    'utb-jardines',
    'utb-cafeteria',
    'utb-plaza',
    'utb-vista-aerea',
  ];
  Timer? _timer;
  int _index = 0;
  bool _visible = false;
  double _dragStart = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible =
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.isCurrentOf(context) ?? true) &&
        !MediaQuery.disableAnimationsOf(context);
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _schedule();

  void _schedule() {
    _timer?.cancel();
    if (!_visible ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _advance(1));
  }

  void _advance(int step) {
    setState(() => _index = (_index + step) % scenes.length);
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      excludeFromSemantics: true,
      onHorizontalDragStart: (details) =>
          _dragStart = details.globalPosition.dx,
      onHorizontalDragEnd: (details) {
        final speed = details.primaryVelocity ?? 0;
        final distance = details.globalPosition.dx - _dragStart;
        if (distance.abs() < 24 && speed.abs() < 100) return;
        _advance((distance.abs() >= 24 ? distance : speed) < 0 ? 1 : -1);
        _schedule();
      },
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 600),
              layoutBuilder: (current, previous) => Stack(
                fit: StackFit.expand,
                children: [...previous, ?current],
              ),
              child: Image.asset(
                'assets/images/${scenes[_index]}.jpg',
                key: ValueKey(_index),
                excludeFromSemantics: true,
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}
