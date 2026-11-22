import 'dart:math';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

enum SupportCategory {
  trip('Viaje'),
  reservation('Reserva'),
  driver('Conductor'),
  app('Aplicación');

  const SupportCategory(this.label);
  final String label;
}

class SupportReport {
  SupportReport({required this.category, required this.description})
    : submissionId = _newSubmissionId();

  final SupportCategory category;
  final String description;
  final String submissionId;

  static String _newSubmissionId() {
    final random = Random.secure();
    return List.generate(
      32,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
  }
}

class SupportRepository {
  const SupportRepository(this._api);

  final ApiClient _api;

  Future<int> submit(SupportReport report) async {
    final result = await _api.post(
      '/support/reports',
      body: {
        'submission_id': report.submissionId,
        'category': report.category.name,
        'description': report.description,
      },
    );
    if (result case {'id': final int id} when id > 0) return id;
    throw const ApiException('No se pudo confirmar el registro del reporte.');
  }
}
