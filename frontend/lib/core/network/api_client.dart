import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../storage/session_store.dart';
import 'api_exception.dart';

/// Cliente HTTP de ROUTB.
///
/// Concentra la dirección del backend, la cabecera de autenticación, el límite
/// de espera y la traducción de fallos a [ApiException]. Los repositorios de
/// cada módulo solo llaman a [get], [post] y [patch].
class ApiClient {
  ApiClient(this._session, {http.Client? client})
      : _client = client ?? http.Client();

  /// El plan gratuito de Render puede tardar 30-50 s en la primera petición
  /// tras 15 min de inactividad, así que el margen es holgado.
  static const Duration timeout = Duration(seconds: 35);

  final SessionStore _session;
  final http.Client _client;

  bool _closed = false;

  /// Dirección del backend en uso.
  String get baseUrl => ApiConfig.baseUrl;

  /// GET con parámetros de consulta opcionales.
  ///
  /// Se omiten los parámetros cuyo valor sea `null` o vacío.
  Future<Object?> get(
    String path, {
    Map<String, String?>? query,
    bool authenticated = true,
  }) {
    return _send(
      () async => _client.get(
        _uri(path, query),
        headers: await _headers(authenticated),
      ),
    );
  }

  /// POST con cuerpo JSON opcional.
  Future<Object?> post(
    String path, {
    Object? body,
    bool authenticated = true,
  }) {
    return _send(
      () async => _client.post(
        _uri(path),
        headers: await _headers(authenticated),
        body: body == null ? null : jsonEncode(body),
      ),
    );
  }

  /// PATCH con cuerpo JSON opcional.
  Future<Object?> patch(
    String path, {
    Object? body,
    bool authenticated = true,
  }) {
    return _send(
      () async => _client.patch(
        _uri(path),
        headers: await _headers(authenticated),
        body: body == null ? null : jsonEncode(body),
      ),
    );
  }

  /// DELETE sin cuerpo. Devuelve `null` cuando el servidor responde 204.
  Future<Object?> delete(String path, {bool authenticated = true}) {
    return _send(
      () async => _client.delete(
        _uri(path),
        headers: await _headers(authenticated),
      ),
    );
  }

  Future<Map<String, String>> _headers(bool authenticated) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (authenticated) {
      final token = await _session.readToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Uri _uri(String path, [Map<String, String?>? query]) {
    final endpoint = path.startsWith('/') ? path : '/$path';
    final parameters = <String, String>{
      for (final entry in (query ?? const <String, String?>{}).entries)
        if (entry.value != null && entry.value!.isNotEmpty)
          entry.key: entry.value!,
    };
    return Uri.parse('$baseUrl$endpoint').replace(
      queryParameters: parameters.isEmpty ? null : parameters,
    );
  }

  /// Ejecuta la petición y normaliza el resultado.
  ///
  /// [request] es diferido porque necesita leer el token, que es asíncrono,
  /// antes de construir la petición.
  Future<Object?> _send(Future<http.Response> Function() request) async {
    if (_closed) throw const ApiException('La conexión está cerrada.');

    final http.Response response;
    try {
      response = await request().timeout(timeout);
    } on TimeoutException {
      throw const ApiException(
        'El servidor tardó demasiado en responder. Intenta de nuevo.',
      );
    } on SocketException {
      throw const ApiException('Sin conexión con el servidor. Revisa tu red.');
    } on http.ClientException catch (error) {
      throw ApiException(
        'No se pudo conectar con el servidor: ${error.message}',
      );
    } on FormatException {
      throw const ApiException('La respuesta del servidor no se pudo leer.');
    }

    final decoded = _decode(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    final failure = ApiException.fromResponse(response.statusCode, decoded);
    throw ApiException(
      failure.detail ?? failure.message,
      statusCode: failure.statusCode,
      detail: failure.detail,
    );
  }

  /// Interpreta el cuerpo de la respuesta. Un cuerpo vacío devuelve `null`.
  Object? _decode(http.Response response) {
    if (response.bodyBytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const ApiException('La respuesta del servidor no se pudo leer.');
    }
  }

  /// Cierra el cliente de HTTP.
  ///
  /// La app vive toda la sesión, así que solo hace falta en pruebas.
  void close() {
    if (_closed) return;
    _closed = true;
    _client.close();
  }
}