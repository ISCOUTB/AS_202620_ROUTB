import 'package:flutter/material.dart';

import 'app/dependencies.dart';
import 'app/routb_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cualquier fallo que no sea un error de la API se registra aquí con su traza
  // completa. Sin esto, un `catch` genérico se come la causa y solo queda un
  // mensaje genérico en pantalla.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('ROUTB · error no controlado');
    debugPrintStack(stackTrace: details.stack, label: 'sin manejar');
  };

  // Las dependencias se montan antes de correr la app para que el tema guardado
  // y la sesión persistida estén disponibles desde la primera pantalla.
  final dependencies = await RoutbDependencies.live();

  runApp(RoutbApp(dependencies: dependencies));
}