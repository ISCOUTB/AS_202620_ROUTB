// Genera las coordenadas del catálogo de barrios con Google Geocoding API.
//
// Uso, desde `frontend/`:
//
//   dart run tool/generate_neighborhoods.dart
//
// La clave se lee de `frontend/.env` (`GOOGLE_MAPS_API_KEY=...`) o de la
// variable de entorno del mismo nombre. El script:
//
//   1. Consulta cada nombre de `lib/core/constants/neighborhood_names.dart`
//      con la consulta "<barrio>, Cartagena de Indias, Bolívar, Colombia".
//   2. Reutiliza `tool/neighborhoods_cache.json` para no repetir peticiones.
//   3. Valida que el resultado caiga en el área de Cartagena/Turbaco.
//   4. Escribe `lib/core/constants/neighborhood_coordinates.g.dart` solo con
//      los barrios encontrados y reporta los que faltan.
//
// No se ejecuta en CI ni en tiempo de ejecución: es una herramienta de
// desarrollo. Respeta una petición por segundo y envía un User-Agent propio.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:frontend/core/constants/neighborhood_names.dart';

const String _userAgent =
    'ROUTB-catalog-generator/1.0 (proyecto academico UTB; contacto: equipo ROUTB)';
const Duration _pace = Duration(milliseconds: 1100);

const Map<String, String> _queryOverrides = <String, String>{
  'Turbaco': 'Turbaco, Bolívar, Colombia',
};

bool _insideCartagena(double lat, double lng) =>
    lat >= 10.0 && lat <= 10.7 && lng >= -75.9 && lng <= -75.2;

String? _readApiKey() {
  final fromEnvironment = Platform.environment['GOOGLE_MAPS_API_KEY'];
  if (fromEnvironment != null && fromEnvironment.trim().isNotEmpty) {
    return fromEnvironment.trim();
  }

  final envFile = File('.env');
  if (!envFile.existsSync()) return null;
  for (final line in envFile.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final separator = trimmed.indexOf('=');
    if (separator <= 0) continue;
    final key = trimmed.substring(0, separator).trim();
    if (key != 'GOOGLE_MAPS_API_KEY') continue;
    final value = trimmed.substring(separator + 1).trim();
    final unquoted = value.replaceAll(RegExp(r'''^["']|["']$'''), '');
    if (unquoted.isNotEmpty) return unquoted;
  }
  return null;
}

Future<Map<String, dynamic>> _loadCache(File file) async {
  if (!file.existsSync()) return <String, dynamic>{};
  try {
    final decoded = jsonDecode(await file.readAsString());
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  } on Object {
    return <String, dynamic>{};
  }
}

Future<({double lat, double lng, String address})?> _geocode(
  String name,
  String apiKey,
  http.Client client,
) async {
  final query =
      _queryOverrides[name] ?? '$name, Cartagena de Indias, Bolívar, Colombia';

  final uri = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
    'address': query,
    'language': 'es',
    'region': 'co',
    'components': 'country:CO',
    'key': apiKey,
  });

  final response = await client
      .get(uri, headers: {'User-Agent': _userAgent})
      .timeout(const Duration(seconds: 12));
  if (response.statusCode != 200) {
    throw HttpException('HTTP ${response.statusCode} para "$query"');
  }

  final data =
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  final status = data['status'] as String? ?? 'UNKNOWN';
  if (status != 'OK') {
    throw StateError('$status para "$query"');
  }

  final results = data['results'] as List?;
  if (results == null) return null;

  for (final result in results) {
    if (result is! Map<String, dynamic>) continue;
    final geometry = result['geometry'] as Map<String, dynamic>?;
    final location = geometry?['location'] as Map<String, dynamic>?;
    final lat = (location?['lat'] as num?)?.toDouble();
    final lng = (location?['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) continue;
    if (!_insideCartagena(lat, lng)) continue;

    final formatted = result['formatted_address'] as String? ?? '';
    final normalized = formatted.toLowerCase();
    if (!normalized.contains('cartagena') &&
        !normalized.contains('turbaco') &&
        !normalized.contains('bolívar') &&
        !normalized.contains('bolivar')) {
      continue;
    }
    return (lat: lat, lng: lng, address: formatted);
  }
  return null;
}

Future<void> _writeCatalog(
  Map<String, ({double lat, double lng, String address})> found,
) async {
  final buffer = StringBuffer()
    ..writeln('// GENERATED FILE - DO NOT EDIT BY HAND.')
    ..writeln('//')
    ..writeln('// Coordenadas verificadas con Google Geocoding API (ADR 0018).')
    ..writeln('// Generado por tool/generate_neighborhoods.dart.')
    ..writeln('//')
    ..writeln('// Para regenerarlo, desde frontend/:')
    ..writeln('//   dart run tool/generate_neighborhoods.dart')
    ..writeln(
      'const Map<String, ({double lat, double lng})> neighborhoodCoordinates =',
    )
    ..writeln('    <String, ({double lat, double lng})>{');

  for (final name in cartagenaNeighborhoodNames) {
    final point = found[name];
    if (point == null) continue;
    buffer
      ..writeln('  // $name -> ${point.address}')
      ..writeln(
        "  '$name': (lat: ${point.lat.toStringAsFixed(6)}, "
        'lng: ${point.lng.toStringAsFixed(6)}),',
      );
  }
  buffer.writeln('};');

  await File('lib/core/constants/neighborhood_coordinates.g.dart')
      .writeAsString(buffer.toString());
}

Future<void> main(List<String> args) async {
  final apiKey = _readApiKey();
  if (apiKey == null) {
    stderr.writeln(
      'Falta GOOGLE_MAPS_API_KEY. Crea frontend/.env con la clave o expórtala '
      'en la variable de entorno.',
    );
    exitCode = 1;
    return;
  }

  final force = args.contains('--force');
  final cacheFile = File('tool/neighborhoods_cache.json');
  final cache = await _loadCache(cacheFile);
  final found = <String, ({double lat, double lng, String address})>{};
  final missing = <String>[];
  final rejected = <String, String>{};
  final client = http.Client();

  try {
    for (var index = 0; index < cartagenaNeighborhoodNames.length; index++) {
      final name = cartagenaNeighborhoodNames[index];
      final cached = cache[name];
      if (!force && cached is Map<String, dynamic>) {
        final lat = (cached['lat'] as num?)?.toDouble();
        final lng = (cached['lng'] as num?)?.toDouble();
        final address = cached['address'] as String? ?? '';
        if (lat != null && lng != null && _insideCartagena(lat, lng)) {
          found[name] = (lat: lat, lng: lng, address: address);
          stdout.writeln(
            '[${index + 1}/${cartagenaNeighborhoodNames.length}] '
            '$name (caché)',
          );
          continue;
        }
      }

      try {
        final point = await _geocode(name, apiKey, client);
        if (point == null) {
          missing.add(name);
          stdout.writeln(
            '[${index + 1}/${cartagenaNeighborhoodNames.length}] '
            '$name -> sin coincidencia',
          );
        } else {
          found[name] = point;
          cache[name] = <String, dynamic>{
            'lat': point.lat,
            'lng': point.lng,
            'address': point.address,
          };
          await cacheFile.writeAsString(
            const JsonEncoder.withIndent('  ').convert(cache),
          );
          stdout.writeln(
            '[${index + 1}/${cartagenaNeighborhoodNames.length}] '
            '$name -> ${point.lat.toStringAsFixed(5)}, '
            '${point.lng.toStringAsFixed(5)}',
          );
        }
      } on Object catch (error) {
        rejected[name] = error.toString();
        stdout.writeln(
          '[${index + 1}/${cartagenaNeighborhoodNames.length}] '
          '$name -> error: $error',
        );
      }

      if (index < cartagenaNeighborhoodNames.length - 1) {
        await Future<void>.delayed(_pace);
      }
    }
  } finally {
    client.close();
  }

  await _writeCatalog(found);

  stdout
    ..writeln('')
    ..writeln('Encontrados: ${found.length}')
    ..writeln('No encontrados (${missing.length}): ${missing.join(', ')}');
  if (rejected.isNotEmpty) {
    stdout.writeln('Con error (${rejected.length}):');
    for (final entry in rejected.entries) {
      stdout.writeln('  ${entry.key}: ${entry.value}');
    }
  }
  stdout.writeln(
    'Catálogo escrito en lib/core/constants/neighborhood_coordinates.g.dart',
  );
}
