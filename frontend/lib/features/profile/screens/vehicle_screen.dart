import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_routes.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/routb_palette.dart';
import '../../../core/widgets/routb_button.dart';
import '../../../core/widgets/routb_field.dart';
import '../../../core/widgets/route_actions.dart';
import '../../auth/data/auth_repository.dart';
import '../data/vehicle_catalog.dart';
import '../data/vehicle_validation.dart';
import '../widgets/profile_form_page.dart';

/// Abre la pantalla para registrar o editar el vehículo del conductor.
///
/// Devuelve el perfil actualizado después de guardar.
Future<UserProfile?> openVehicleScreen({
  required BuildContext context,
  UserProfile? profile,
  bool activate = false,
  required AuthRepository auth,
}) => context.pushFromCurrent(
  RoutbPageRoute<UserProfile>(
    child: _VehicleScreen(profile: profile, activate: activate, auth: auth),
  ),
);

class _VehicleScreen extends StatefulWidget {
  const _VehicleScreen({
    required this.profile,
    required this.activate,
    required this.auth,
  });

  final UserProfile? profile;
  final bool activate;
  final AuthRepository auth;

  @override
  State<_VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<_VehicleScreen> {
  // Los nombres describen el acabado y las muestras son orientativas.
  static const _colors = {
    'Blanco': Color(0xFFF4F4F2),
    'Blanco perla': Color(0xFFEEE7DB),
    'Plata': Color(0xFFBCC3CB),
    'Gris': Color(0xFF86888B),
    'Gris claro': Color(0xFFA5ACB4),
    'Gris oscuro': Color(0xFF515861),
    'Gris grafito': Color(0xFF363C42),
    'Gris taupé': Color(0xFF83786F),
    'Negro': Color(0xFF161719),
    'Negro metalizado': Color(0xFF282A2F),
    'Azul': Color(0xFF1760AB),
    'Azul claro': Color(0xFF78AED3),
    'Azul oscuro': Color(0xFF1A2A50),
    'Azul grisáceo': Color(0xFF536C80),
    'Rojo': Color(0xFFB7232A),
    'Rojo vino': Color(0xFF681F32),
    'Verde': Color(0xFF367054),
    'Verde oliva': Color(0xFF636B46),
    'Verde oscuro': Color(0xFF2E483C),
    'Beige': Color(0xFFD3BC99),
    'Arena': Color(0xFFB5A78E),
    'Marrón': Color(0xFF735345),
    'Amarillo': Color(0xFFF1C53A),
    'Naranja': Color(0xFFE16B2E),
    'Bicolor': null,
  };

  final _modelFocus = FocusNode();
  final _plateFocus = FocusNode();
  final _colorFocus = FocusNode();
  late final _model = TextEditingController(
    text: widget.profile?.vehicleModel ?? '',
  );
  late final _plate = TextEditingController(
    text: widget.profile?.vehiclePlate ?? '',
  );
  late final _modelInput = Listenable.merge([_model, _modelFocus]);
  late final _catalog = loadVehicleModels(DefaultAssetBundle.of(context));
  late final _savedColor = widget.profile?.vehicleColor?.trim() ?? '';
  late String _color = _savedColor;
  late final Map<String, Color?> _availableColors = {
    ..._colors,
    if (_savedColor.isNotEmpty &&
        !_colors.keys.any(
          (name) => name.toLowerCase() == _savedColor.toLowerCase(),
        ))
      _savedColor: null,
  };

  String? _modelError;
  String? _plateError;
  String? _colorError;
  bool _saving = false;
  String? _saveError;

  @override
  void dispose() {
    _modelFocus.dispose();
    _plateFocus.dispose();
    _colorFocus.dispose();
    _model.dispose();
    _plate.dispose();
    super.dispose();
  }

  bool get _hasVehicle => widget.profile?.hasVehicle ?? false;

  bool _validate() {
    final modelError = validateVehicleModel(_model.text);
    final plateError = validateVehiclePlate(_plate.text);
    final colorError = validateVehicleColor(_color);

    setState(() {
      _modelError = modelError;
      _plateError = plateError;
      _colorError = colorError;
    });
    final invalidField = modelError != null
        ? _modelFocus
        : plateError != null
        ? _plateFocus
        : colorError != null
        ? _colorFocus
        : null;
    if (invalidField == null) return true;
    invalidField.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final fieldContext = invalidField.context;
      if (mounted && fieldContext != null && fieldContext.mounted) {
        Scrollable.ensureVisible(fieldContext, alignment: 0.15);
      }
    });
    return false;
  }

  Future<void> _save() async {
    if (_saving || !_validate()) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final updated = await widget.auth.updateVehicle(
        activate: widget.activate,
        model: _model.text,
        plate: normalizeVehiclePlate(_plate.text),
        color: _color,
      );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _saveError = error.message);
    } on Exception catch (error, stack) {
      logFailure('el registro del vehículo', error, stack);
      if (!mounted) return;
      setState(() => _saveError = describeFailure(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clear() async {
    if (_saving || !context.canOpenRoute) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Quitar el vehículo?'),
        content: const Text(
          'El pasajero con cupo confirmado dejará de ver el modelo y la placa. '
          'Puedes volver a registrarlo cuando quieras.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Mantener'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Quitar',
              style: TextStyle(color: dialogContext.palette.rose),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final updated = await widget.auth.updateVehicle();
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _saveError = error.message);
    } on Exception catch (error, stack) {
      logFailure('la eliminación del vehículo', error, stack);
      if (!mounted) return;
      setState(() => _saveError = describeFailure(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final footer = RoutbFormFooter(
      error: _saveError,
      hint: 'Estos datos se comparten con pasajeros con cupo confirmado.',
      action: RoutbButton(
        label: widget.activate
            ? 'Habilitar modo conductor'
            : _hasVehicle
            ? 'Guardar cambios'
            : 'Guardar vehículo',
        icon: Icons.check_rounded,
        busy: _saving,
        onPressed: _save,
      ),
    );

    return ProfileFormPage(
      busy: _saving,
      title: widget.activate
          ? 'Quiero ser conductor'
          : _hasVehicle
          ? 'Editar vehículo'
          : 'Registrar vehículo',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RoutbField(
            icon: Icons.directions_car_filled_rounded,
            label: 'Marca y modelo',
            hint: 'Ej. Chevrolet Spark',
            controller: _model,
            focusNode: _modelFocus,
            inputFormatters: [LengthLimitingTextInputFormatter(50)],
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _plateFocus.requestFocus(),
            errorText: _modelError,
            onChanged: (_) {
              if (_modelError != null) setState(() => _modelError = null);
            },
          ),
          ListenableBuilder(
            listenable: _modelInput,
            builder: (context, _) {
              if (!_modelFocus.hasFocus || _model.text.trim().length < 2) {
                return const SizedBox.shrink();
              }
              return FutureBuilder<List<String>>(
                future: _catalog,
                builder: (context, snapshot) {
                  final matches = suggestVehicleModels(
                    snapshot.data ?? const [],
                    _model.text,
                  ).toList();
                  if (matches.isEmpty) return const SizedBox.shrink();
                  return Column(
                    children: [
                      for (final model in matches)
                        ListTile(
                          title: Text(model),
                          trailing: const Icon(
                            Icons.north_west_rounded,
                            size: 16,
                          ),
                          onTap: () {
                            _model.text = model;
                            setState(() => _modelError = null);
                            _plateFocus.requestFocus();
                          },
                        ),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(height: 12),
          RoutbField(
            icon: Icons.badge_outlined,
            label: 'Placa',
            hint: 'Ej. ABC-123',
            controller: _plate,
            focusNode: _plateFocus,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.next,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\- ]')),
              const _PlateFormatter(),
              LengthLimitingTextInputFormatter(8),
            ],
            onSubmitted: (_) => _colorFocus.requestFocus(),
            errorText: _plateError,
            onChanged: (_) {
              if (_plateError != null) setState(() => _plateError = null);
            },
          ),
          const SizedBox(height: 12),
          Text('Color', style: Theme.of(context).textTheme.titleSmall),
          if (_colorError case final error?)
            Text(error, style: TextStyle(color: palette.onRoseSurface)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              for (final (index, entry) in _availableColors.entries.indexed)
                ChoiceChip(
                  focusNode: index == 0 ? _colorFocus : null,
                  label: Text(entry.key),
                  avatar: entry.value == null
                      ? const Icon(Icons.palette_outlined, size: 18)
                      : Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: entry.value,
                            border: Border.all(color: palette.muted),
                          ),
                        ),
                  selected: _color.toLowerCase() == entry.key.toLowerCase(),
                  onSelected: (_) => setState(() {
                    _color = entry.key;
                    _colorError = null;
                  }),
                ),
            ],
          ),
          if (_hasVehicle) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: RoutbTextAction(
                label: 'Quitar vehículo',
                icon: Icons.delete_outline_rounded,
                color: palette.rose,
                onPressed: _saving ? null : _clear,
              ),
            ),
          ],
        ],
      ),
      footer: footer,
    );
  }
}

class _PlateFormatter extends TextInputFormatter {
  const _PlateFormatter();

  static final _separators = RegExp(r'[- ]');
  static final _startsWithLetters = RegExp(r'^[A-Z]{3}\d');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed) return newValue;
    final raw = newValue.text;
    final compact = raw.replaceAll(_separators, '').toUpperCase();
    final hasDash = _startsWithLetters.hasMatch(compact);
    final formatted = hasDash
        ? '${compact.substring(0, 3)}-${compact.substring(3)}'
        : compact;
    if (!newValue.selection.isValid) return newValue.copyWith(text: formatted);
    int offsetOf(int offset) {
      final count = raw.substring(0, offset).replaceAll(_separators, '').length;
      return count + (hasDash && count > 3 ? 1 : 0);
    }

    return newValue.copyWith(
      text: formatted,
      selection: newValue.selection.copyWith(
        baseOffset: offsetOf(newValue.selection.baseOffset),
        extentOffset: offsetOf(newValue.selection.extentOffset),
      ),
    );
  }
}
