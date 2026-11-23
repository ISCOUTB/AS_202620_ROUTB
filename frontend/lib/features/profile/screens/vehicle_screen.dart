import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_routes.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/routb_palette.dart';
import '../../../core/theme/routb_text.dart';
import '../../../core/theme/routb_theme.dart';
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

  static const _otherBrand = 'OTRA';
  static const _otherModel = 'Otro modelo';
  static const _vehicleIcon = Icons.directions_car_filled_rounded;

  final _brandFocus = FocusNode();
  final _brandChoiceFocus = FocusNode();
  final _modelChoiceFocus = FocusNode();
  final _modelFocus = FocusNode();
  final _plateFocus = FocusNode();
  final _colorFocus = FocusNode();
  late final _savedModel = widget.profile?.vehicleModel ?? '';
  late final _savedParts = splitVehicleCatalogText(_savedModel);
  late String? _selectedBrand = _savedModel.isEmpty
      ? null
      : vehicleCatalog.containsKey(_savedParts.brand)
      ? _savedParts.brand
      : _otherBrand;
  late String? _selectedModel = _initialModel();
  late final _brand = TextEditingController(
    text: _selectedBrand == _otherBrand ? _savedParts.brand : '',
  );
  late final _model = TextEditingController(
    text: _usesManualModel ? _savedParts.model : '',
  );
  late final _plate = TextEditingController(
    text: widget.profile?.vehiclePlate ?? '',
  );
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

  bool _vehicleIdentityChanged = false;
  String? _brandError;
  String? _modelError;
  String? _plateError;
  String? _colorError;
  bool _saving = false;
  String? _saveError;

  bool get _usesManualModel =>
      _selectedBrand == _otherBrand || _selectedModel == _otherModel;

  String? _initialModel() {
    final models = vehicleCatalog[_selectedBrand];
    if (models == null || _savedParts.model.isEmpty) return null;
    final saved = normalizeVehicleCatalogText(_savedParts.model);
    for (final model in models) {
      if (normalizeVehicleCatalogText(model) == saved) return model;
    }
    return _otherModel;
  }

  void _changeBrand(String? value) {
    if (_selectedBrand == value) return;
    setState(() {
      _selectedBrand = value;
      _selectedModel = null;
      _brand.clear();
      _model.clear();
      _brandError = null;
      _modelError = null;
      _vehicleIdentityChanged = true;
    });
  }

  void _changeModel(String? value) {
    if (_selectedModel == value) return;
    setState(() {
      _selectedModel = value;
      _model.clear();
      _modelError = null;
      _vehicleIdentityChanged = true;
    });
  }

  String get _brandValue =>
      _selectedBrand == _otherBrand ? _brand.text.trim() : _selectedBrand ?? '';

  String get _modelValue =>
      _usesManualModel ? _model.text.trim() : _selectedModel ?? '';

  String get _vehicleValue => !_vehicleIdentityChanged && _savedModel.isNotEmpty
      ? _savedModel
      : '$_brandValue $_modelValue';

  @override
  void dispose() {
    _brandFocus.dispose();
    _brandChoiceFocus.dispose();
    _modelChoiceFocus.dispose();
    _brand.dispose();
    _modelFocus.dispose();
    _plateFocus.dispose();
    _colorFocus.dispose();
    _model.dispose();
    _plate.dispose();
    super.dispose();
  }

  bool get _hasVehicle => widget.profile?.hasVehicle ?? false;

  bool _validate() {
    final brandError = _brandValue.isEmpty
        ? (_selectedBrand == _otherBrand
              ? 'Escribe la marca del vehículo'
              : 'Selecciona una marca')
        : normalizeVehicleCatalogText(_brandValue) == 'otra'
        ? 'Escribe la marca real del vehículo'
        : null;
    final modelError = _modelValue.isEmpty
        ? (_usesManualModel
              ? 'Escribe el modelo del vehículo'
              : 'Selecciona un modelo')
        : normalizeVehicleCatalogText(_modelValue) == 'otro modelo'
        ? 'Escribe el modelo real del vehículo'
        : brandError == null
        ? validateVehicleModel(_vehicleValue)
        : null;
    final plateError = validateVehiclePlate(_plate.text);
    final colorError = validateVehicleColor(_color);

    setState(() {
      _brandError = brandError;
      _modelError = modelError;
      _plateError = plateError;
      _colorError = colorError;
    });
    final invalidField = brandError != null
        ? (_selectedBrand == _otherBrand ? _brandFocus : _brandChoiceFocus)
        : modelError != null
        ? (_usesManualModel ? _modelFocus : _modelChoiceFocus)
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
        model: _vehicleValue,
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
          _VehicleSelect(
            label: 'Marca',
            hint: 'Selecciona una marca',
            options: [...vehicleCatalog.keys, _otherBrand],
            selected: _selectedBrand,
            focusNode: _brandChoiceFocus,
            errorText: _selectedBrand == _otherBrand ? null : _brandError,
            onChanged: _saving ? null : _changeBrand,
          ),
          if (_selectedBrand == _otherBrand) ...[
            const SizedBox(height: 12),
            RoutbField(
              key: const ValueKey('vehicle-brand-input'),
              icon: _vehicleIcon,
              label: 'Escribe la marca',
              hint: 'Ej. BYD',
              controller: _brand,
              focusNode: _brandFocus,
              inputFormatters: [LengthLimitingTextInputFormatter(50)],
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _modelFocus.requestFocus(),
              errorText: _brandError,
              onChanged: (_) => setState(() {
                _vehicleIdentityChanged = true;
                _brandError = null;
                _modelError = null;
              }),
            ),
          ] else ...[
            const SizedBox(height: 12),
            _VehicleSelect(
              label: 'Modelo',
              hint: 'Selecciona un modelo',
              options: [
                ...?vehicleCatalog[_selectedBrand],
                if (_selectedBrand != null) _otherModel,
              ],
              selected: _selectedModel,
              focusNode: _modelChoiceFocus,
              errorText: _usesManualModel ? null : _modelError,
              onChanged: _saving || _selectedBrand == null
                  ? null
                  : _changeModel,
            ),
          ],
          if (_usesManualModel) ...[
            const SizedBox(height: 12),
            RoutbField(
              key: const ValueKey('vehicle-model-input'),
              icon: _vehicleIcon,
              label: 'Escribe el modelo',
              hint: _selectedBrand == _otherBrand
                  ? 'Ej. Dolphin Mini'
                  : 'Modelo del vehículo',
              controller: _model,
              focusNode: _modelFocus,
              inputFormatters: [LengthLimitingTextInputFormatter(50)],
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _plateFocus.requestFocus(),
              errorText: _modelError,
              onChanged: (_) => setState(() {
                _vehicleIdentityChanged = true;
                _modelError = null;
              }),
            ),
          ],
          const SizedBox(height: 12),
          RoutbField(
            key: const ValueKey('vehicle-plate-input'),
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

class _VehicleSelect extends StatelessWidget {
  const _VehicleSelect({
    required this.label,
    required this.hint,
    required this.options,
    required this.selected,
    required this.focusNode,
    required this.errorText,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final List<String> options;
  final String? selected;
  final FocusNode focusNode;
  final String? errorText;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final placeholder = Text(
      hint,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: RoutbText.copy(14, color: palette.muted),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            label,
            style: RoutbText.copy(
              13,
              color: palette.ink,
              weight: FontWeight.w600,
            ),
          ),
        ),
        ListenableBuilder(
          listenable: focusNode,
          builder: (context, child) => AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: RoutbTheme.fieldHeight,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: focusNode.hasFocus ? palette.card : palette.surface,
              borderRadius: BorderRadius.circular(RoutbTheme.radiusField),
              border: Border.all(
                color: errorText != null
                    ? palette.rose
                    : focusNode.hasFocus
                    ? palette.brand
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: child,
          ),
          child: Row(
            children: [
              Icon(
                Icons.directions_car_filled_rounded,
                size: 18,
                color: palette.muted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  label: label,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selected,
                      isExpanded: true,
                      hint: placeholder,
                      disabledHint: placeholder,
                      focusNode: focusNode,
                      focusColor: Colors.transparent,
                      dropdownColor: palette.card,
                      iconEnabledColor: palette.muted,
                      iconDisabledColor: palette.muted,
                      borderRadius: BorderRadius.circular(
                        RoutbTheme.radiusField,
                      ),
                      menuMaxHeight: 320,
                      style: RoutbText.copy(14, color: palette.ink),
                      items: [
                        for (final option in options)
                          DropdownMenuItem(
                            value: option,
                            child: Text(
                              option,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: onChanged,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (errorText case final error?)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(error, style: RoutbText.copy(12, color: palette.rose)),
          ),
      ],
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
