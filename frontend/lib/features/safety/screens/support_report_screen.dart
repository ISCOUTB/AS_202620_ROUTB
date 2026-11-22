import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/routb_palette.dart';
import '../../../core/widgets/routb_button.dart';
import '../../../core/widgets/routb_card.dart';
import '../data/support_repository.dart';
import 'safety_detail_page.dart';

class SupportReportScreen extends StatefulWidget {
  const SupportReportScreen({required this.submit, super.key});

  final Future<int> Function(SupportReport) submit;

  @override
  State<SupportReportScreen> createState() => _SupportReportScreenState();
}

class _SupportReportScreenState extends State<SupportReportScreen> {
  final _form = GlobalKey<FormState>();
  final _description = TextEditingController();
  SupportReport? _draft;
  SupportCategory? _category;
  bool _busy = false;
  String? _error;
  int? _receipt;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final category = _category!;
    final description = _description.text.trim();
    final previous = _draft;
    final report =
        previous != null &&
            previous.category == category &&
            previous.description == description
        ? previous
        : SupportReport(category: category, description: description);
    _draft = report;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final receipt = await widget.submit(report);
      if (mounted) setState(() => _receipt = receipt);
    } on Exception catch (error) {
      if (mounted) setState(() => _error = describeFailure(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final receipt = _receipt;
    return PopScope(
      canPop: !_busy,
      child: SafetyDetailPage(
        title: 'Reportar un problema',
        children: [
          if (receipt != null)
            RoutbCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    liveRegion: true,
                    child: Text('Reporte registrado. Folio #$receipt.'),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copiar folio'),
                    onPressed: () async {
                      try {
                        await Clipboard.setData(
                          ClipboardData(text: '#$receipt'),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Folio copiado.')),
                          );
                        }
                      } on PlatformException {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('No se pudo copiar el folio.'),
                            ),
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  RoutbButton(
                    label: 'Volver',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            )
          else
            RoutbCard(
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Incluye la fecha y la ruta si ayudan a identificar lo ocurrido. Evita incluir contraseñas o códigos de acceso.',
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<SupportCategory>(
                      decoration: const InputDecoration(
                        labelText: 'Tipo de problema',
                      ),
                      isExpanded: true,
                      items: [
                        for (final category in SupportCategory.values)
                          DropdownMenuItem(
                            value: category,
                            child: Text(category.label),
                          ),
                      ],
                      onChanged: _busy ? null : (value) => _category = value,
                      validator: (value) =>
                          value == null ? 'Elige un tipo de problema.' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _description,
                      readOnly: _busy,
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 4,
                      maxLines: 8,
                      maxLength: 2000,
                      validator: (value) => (value ?? '').trim().length < 10
                          ? 'Escribe al menos 10 caracteres.'
                          : null,
                    ),
                    if (_error case final error?) ...[
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          error,
                          style: TextStyle(color: palette.onRoseSurface),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 8),
                    RoutbButton(
                      label: 'Enviar reporte',
                      busy: _busy,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
