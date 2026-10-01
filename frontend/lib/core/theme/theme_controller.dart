import 'package:flutter/material.dart';

import '../storage/session_store.dart';

/// Modo del tema de la app, con persistencia.
///
/// Arranca en [ThemeMode.system] salvo que la persona haya elegido otro modo;
/// la elección se guarda en el dispositivo con [SessionStore].
class ThemeController extends ChangeNotifier {
  ThemeController(this._store);

  /// Crea el controlador con el modo ya guardado en el dispositivo.
  static Future<ThemeController> load(SessionStore store) async {
    final controller = ThemeController(store);
    controller._mode = await store.readThemeMode();
    return controller;
  }

  final SessionStore _store;

  ThemeMode _mode = ThemeMode.system;

  /// Modo activo.
  ThemeMode get mode => _mode;

  /// `true` mientras el tema siga al del sistema operativo.
  bool get followsSystem => _mode == ThemeMode.system;

  /// Fija el modo y lo guarda.
  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    await _store.saveThemeMode(mode);
  }

  /// Alterna entre claro y oscuro a partir de la luminosidad que se está
  /// mostrando ahora.
  Future<void> toggle(Brightness current) => setMode(
        current == Brightness.dark ? ThemeMode.light : ThemeMode.dark,
      );
}

/// Publica el [ThemeController] en el árbol de widgets.
///
/// Permite leerlo con `RoutbScope.of(context)` sin añadir dependencias ni
/// pasar el controlador por parámetro en cada constructor.
class RoutbScope extends InheritedNotifier<ThemeController> {
  const RoutbScope({
    required ThemeController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  /// Controlador del tema para el contexto dado.
  ///
  /// Lanza si se usa fuera de [RoutbScope].
  static ThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<RoutbScope>();
    assert(scope != null, 'No hay RoutbScope en el árbol de widgets.');
    return scope!.notifier!;
  }

  /// Controlador del tema sin establecer dependencia.
  ///
  /// Pensado para manejadores de eventos, donde no hace falta redibujar.
  static ThemeController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<RoutbScope>();
    assert(scope != null, 'No hay RoutbScope en el árbol de widgets.');
    return scope!.notifier!;
  }
}