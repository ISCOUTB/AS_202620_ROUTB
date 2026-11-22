import 'package:flutter/material.dart';

extension RouteActions on BuildContext {
  /// Acepta acciones de la ruta visible aunque la animación aún no haya empezado.
  bool get canOpenRoute => mounted && (ModalRoute.of(this)?.isCurrent ?? true);

  Future<T?> pushFromCurrent<T>(Route<T> route) async {
    if (!canOpenRoute) return null;
    return Navigator.of(this).push<T>(route);
  }
}
