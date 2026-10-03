import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Error devuelto por [ApiClient] cuando una llamada a la API no termina bien.
///
/// El backend responde con `{"detail": "..."}`; el detalle puede ser texto o
/// una lista de errores de validación, y ambos casos se normalizan a un
/// mensaje que la interfaz pueda mostrar tal cual.
@immutable
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.detail});

  /// Crea el error a partir de una respuesta fallida de la API.
  factory ApiException.fromResponse(int statusCode, Object? body) {
    return ApiException(
      _messageFor(statusCode),
      statusCode: statusCode,
      detail: _detailOf(body),
    );
  }

  /// Mensaje listo para mostrar.
  final String message;

  /// Código HTTP, o `null` si el fallo fue de conexión.
  final int? statusCode;

  /// Texto original que devolvió el backend, si lo hubo.
  final String? detail;

  /// `true` cuando el fallo fue de red y no del servidor.
  bool get isNetworkError => statusCode == null;

  /// `true` cuando el token venció o nunca se envió.
  bool get isUnauthorized => statusCode == 401;

  /// `true` cuando la operación chocó con el estado actual: cupo tomado,
  /// solicitud duplicada, sin cupos para aceptar.
  bool get isConflict => statusCode == 409;

  /// `true` cuando el recurso no existe o no pertenece a quien pregunta.
  bool get isNotFound => statusCode == 404;

  /// `true` cuando el backend rechazó los datos enviados.
  bool get isValidation => statusCode == 400 || statusCode == 422;

  @override
  String toString() =>
      'ApiException(${statusCode ?? 'sin respuesta'}): $message';

  static String _messageFor(int statusCode) => switch (statusCode) {
        400 => 'La solicitud no es válida.',
        401 => 'Tu sesión expiró. Ingresa de nuevo.',
        403 => 'No tienes permiso para esta acción.',
        404 => 'No encontramos ese recurso.',
        409 => 'La acción no se pudo completar.',
        >= 500 => 'El servidor está teniendo problemas. Intenta en un momento.',
        _ => 'No se pudo completar la solicitud.',
      };

  /// Extrae `detail` de un cuerpo de FastAPI.
  ///
  /// Acepta `"texto"`, `[{"msg": "...", "loc": [...]}]` y `null`.
  static String? _detailOf(Object? body) {
    if (body is! Map<Object?, Object?>) return null;
    final detail = body['detail'];

    if (detail is String) return detail;

    if (detail is List && detail.isNotEmpty && detail.first is Map) {
      final first = detail.first as Map<Object?, Object?>;
      final message = first['msg'];
      if (message is! String) return null;

      final location = first['loc'];
      if (location is List && location.isNotEmpty) {
        final field = location.last;
        if (field is String && field != 'body') return '$field: $message';
      }
      return message;
    }

    return null;
  }
}

/// Traduce cualquier excepción a un mensaje que la persona pueda usar.
///
/// Los fallos que no son de la API solían terminar en un `catch (_)` que
/// devolvía «No se pudo completar la solicitud», sin más rastro. Esta función
/// nombra el problema real cuando se reconoce, y el resto queda registrado en
/// consola con su traza para poder diagnosticarlo.
String describeFailure(Object error) {
  if (error is ApiException) return error.message;

  // El almacenamiento local no respondió: el plugin de la plataforma no está
  // disponible, así que la sesión no se puede guardar.
  if (error is MissingPluginException) {
    return 'El almacenamiento local no está disponible en este dispositivo. '
        'Reinicia la app o prueba en otro dispositivo.';
  }

  if (error is AssertionError) {
    // Fallo interno de la app: no hay nada que la persona pueda hacer, pero hay
    // que dejarlo escrito en consola.
    return 'Ocurrió un problema interno. Revisa la consola de la app.';
  }

  return 'No se pudo completar la solicitud.';
}

/// Registra un fallo con su tipo y su traza.
///
/// Se llama en el `catch` genérico: aunque el mensaje en pantalla sea genérico,
/// la consola deja constancia de qué pasó exactamente y dónde.
void logFailure(String donde, Object error, [StackTrace? stack]) {
  debugPrint('ROUTB · fallo en $donde');
  debugPrint('  tipo: ${error.runtimeType}');
  debugPrint('  error: $error');
  if (stack != null) {
    debugPrintStack(stackTrace: stack, label: '  traza de $donde');
  }
}