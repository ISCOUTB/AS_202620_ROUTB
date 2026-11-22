import 'dart:convert';

import 'package:flutter/services.dart';

/// Carga local de marca y línea del SIBGA. No usa datos personales del vehículo.
Future<List<String>> loadVehicleModels(AssetBundle bundle) async {
  final source = await bundle.load('assets/data/vehicle_models.json');
  final json = utf8.decode(
    source.buffer.asUint8List(source.offsetInBytes, source.lengthInBytes),
  );
  return (jsonDecode(json) as List<dynamic>).cast<String>();
}

Iterable<String> suggestVehicleModels(List<String> models, String input) {
  final normalized = _searchText(input.trim());
  if (normalized.length < 2) return const [];
  final words = normalized.split(RegExp(r'\s+'));
  final prefixes = <String>[];
  final matches = <String>[];
  for (final model in models) {
    final name = _searchText(model);
    if (name == normalized || !words.every(name.contains)) continue;
    (name.startsWith(normalized) ? prefixes : matches).add(model);
  }
  return prefixes.followedBy(matches).take(6);
}

String _searchText(String text) {
  const latin = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u'};
  return text.toLowerCase().replaceAllMapped(
    RegExp('[áéíóúü]'),
    (match) => latin[match[0]]!,
  );
}
