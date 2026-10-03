import 'package:flutter/material.dart';

import '../models/trip_status.dart';
import '../theme/routb_palette.dart';
import '../theme/routb_text.dart';
import 'routb_anim.dart';

/// `.live`: píldora de disponibilidad sobre el mapa.
///
/// El punto late cuando el viaje está en curso, se queda quieto y en ámbar
/// cuando está programado, y cambia a rosa cuando se cancela.
class LivePill extends StatelessWidget {
  const LivePill({required this.phase, this.onDark = true, super.key});

  /// Fase del viaje.
  final TripPhase phase;

  /// `true` cuando se pinta encima del hero, donde el fondo es oscuro.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    final (
      Color background,
      Color foreground,
      Color dot,
      bool pulsing,
    ) = switch (phase) {
      TripPhase.onCourse => (
        onDark ? const Color(0x382FD3A0) : palette.mintSurface,
        onDark ? const Color(0xFF8CF7D1) : palette.onMintSurface,
        palette.mint,
        true,
      ),
      TripPhase.scheduled => (
        onDark ? const Color(0x38FF9F1C) : palette.amberSurface,
        onDark ? const Color(0xFFFFD08A) : palette.onAmberSurface,
        palette.amber,
        false,
      ),
      TripPhase.completed => (
        onDark ? const Color(0x28FFFFFF) : palette.surface,
        onDark ? const Color(0xD9FFFFFF) : palette.muted,
        onDark ? const Color(0xD9FFFFFF) : palette.muted,
        false,
      ),
      TripPhase.cancelled => (
        onDark ? const Color(0x38FF5C7A) : palette.roseSurface,
        onDark ? const Color(0xFFFFB3C0) : palette.onRoseSurface,
        palette.rose,
        false,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pulsing)
            PulsingDot(color: dot, size: 7)
          else
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
          const SizedBox(width: 6),
          Text(
            phase.label,
            style: RoutbText.copy(
              11,
              color: foreground,
              weight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Atajo para elegir los colores de la píldora según la fase.
extension TripPhaseColors on TripPhase {
  /// Par de colores (relleno, texto) en tema claro.
  (Color, Color) get lightColors => switch (this) {
    TripPhase.onCourse => (const Color(0xFFD5FBEC), const Color(0xFF0B6B4C)),
    TripPhase.scheduled => (const Color(0xFFFFF1D6), const Color(0xFF9A5A00)),
    TripPhase.completed => (const Color(0xFFE9E7F0), const Color(0xFF59566A)),
    TripPhase.cancelled => (const Color(0xFFFFE0E6), const Color(0xFFB3263F)),
  };
}
