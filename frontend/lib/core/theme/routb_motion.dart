import 'package:flutter/animation.dart';

/// Duraciones y curvas de las animaciones de ROUTB.
///
/// Los valores reproducen los del diseño: entrada escalonada de 90 ms por
/// tarjeta, transición de vista de 400 ms con curva `cubic-bezier(.3,.8,.3,1)`
/// y pulsos de 1,4 s.
///
/// Todas las animaciones de la app deben respetar
/// `MediaQuery.disableAnimationsOf(context)`, que se activa cuando el sistema
/// pide movimiento reducido.
abstract final class RoutbMotion {
  /// Curva equivalente a `cubic-bezier(.3,.8,.3,1)`.
  static const Curve standard = Cubic(0.3, 0.8, 0.3, 1);

  /// Entrada de una tarjeta.
  static const Duration enter = Duration(milliseconds: 500);

  /// Retardo entre tarjeta y tarjeta.
  static const Duration stagger = Duration(milliseconds: 90);

  /// Cambio de vista del carrusel de acceso.
  static const Duration view = Duration(milliseconds: 400);

  /// Hoja inferior.
  static const Duration sheet = Duration(milliseconds: 450);

  /// Aparición y desaparición de un aviso.
  static const Duration toast = Duration(milliseconds: 300);

  /// Cuánto permanece un aviso en pantalla.
  static const Duration toastVisible = Duration(milliseconds: 2400);

  /// Pulso del indicador de disponibilidad.
  static const Duration pulse = Duration(milliseconds: 1400);

  /// Recorrido del punto animado sobre el trayecto.
  static const Duration travel = Duration(milliseconds: 2400);

  /// Escala al pulsar, equivalente a `transform: scale(.86)`.
  static const double pressScale = 0.86;

  /// Aparición de un cupo recién ocupado.
  static const Duration seatPop = Duration(milliseconds: 400);
}