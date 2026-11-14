import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/routb_palette.dart';
import '../../../core/theme/routb_text.dart';
import '../../../core/widgets/routb_button.dart';
import '../../../core/widgets/routb_card.dart';
import '../../../core/widgets/routb_field.dart';
import '../../../core/widgets/routb_sheet.dart';
import '../../../core/widgets/routb_toast.dart';
import '../../auth/data/auth_repository.dart';
import '../data/vehicle_validation.dart';

/// Abre la hoja para registrar o editar el vehículo del conductor.
///
/// Recibe el repositorio de autenticación desde la pantalla porque las rutas
/// modales viven fuera del `RoutbScopeDependencies`. Devuelve el perfil
/// actualizado cuando el backend confirma el cambio, o `null` si se cerró sin
/// guardar.
Future<UserProfile?> showVehicleSheet({
  required BuildContext context,
  required UserProfile profile,
  required AuthRepository auth,
}) {
  return showModalBottomSheet<UserProfile>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    showDragHandle: false,
    backgroundColor: context.palette.surface,
    barrierColor: const Color(0x8C0A0820),
    constraints: const BoxConstraints(maxWidth: 640),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      builder: (context, scrollController) => _VehicleSheet(
        profile: profile,
        auth: auth,
        scrollController: scrollController,
      ),
    ),
  );
}

class _VehicleSheet extends StatefulWidget {
  const _VehicleSheet({
    required this.profile,
    required this.auth,
    required this.scrollController,
  });

  final UserProfile profile;
  final AuthRepository auth;
  final ScrollController scrollController;

  @override
  State<_VehicleSheet> createState() => _VehicleSheetState();
}

class _VehicleSheetState extends State<_VehicleSheet> {
  late final TextEditingController _model = TextEditingController(
    text: widget.profile.vehicleModel ?? '',
  );
  late final TextEditingController _plate = TextEditingController(
    text: widget.profile.vehiclePlate ?? '',
  );
  late final TextEditingController _color = TextEditingController(
    text: widget.profile.vehicleColor ?? '',
  );

  String? _modelError;
  String? _plateError;
  String? _colorError;
  bool _saving = false;

  @override
  void dispose() {
    _model.dispose();
    _plate.dispose();
    _color.dispose();
    super.dispose();
  }

  bool get _hasVehicle => widget.profile.hasVehicle;

  bool _validate() {
    final modelError = validateVehicleModel(_model.text);
    final plateError = validateVehiclePlate(_plate.text);
    final colorError = validateVehicleColor(_color.text);

    setState(() {
      _modelError = modelError;
      _plateError = plateError;
      _colorError = colorError;
    });
    return modelError == null && plateError == null && colorError == null;
  }

  Future<void> _save() async {
    if (_saving || !_validate()) return;
    setState(() => _saving = true);
    try {
      final updated = await widget.auth.updateVehicle(
        model: _model.text,
        plate: normalizeVehiclePlate(_plate.text),
        color: _color.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } on ApiException catch (error) {
      if (!mounted) return;
      RoutbToast.show(context, error.message);
    } on Exception catch (error, stack) {
      logFailure('el registro del vehículo', error, stack);
      if (!mounted) return;
      RoutbToast.show(context, describeFailure(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clear() async {
    if (_saving) return;
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

    setState(() => _saving = true);
    try {
      final updated = await widget.auth.updateVehicle();
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } on ApiException catch (error) {
      if (!mounted) return;
      RoutbToast.show(context, error.message);
    } on Exception catch (error, stack) {
      logFailure('la eliminación del vehículo', error, stack);
      if (!mounted) return;
      RoutbToast.show(context, describeFailure(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return RoutbSheetScaffold(
      title: _hasVehicle ? 'Editar vehículo' : 'Registrar vehículo',
      subtitle:
          'Solo lo verá el pasajero cuyo cupo confirmes. No se muestra en el '
          'listado público de viajes.',
      scrollController: widget.scrollController,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const RoutbHint(
            'El modelo, el color y la placa ayudan a que te reconozcan al '
            'llegar al punto de encuentro.',
          ),
          const SizedBox(height: 16),
          RoutbField(
            icon: Icons.directions_car_filled_rounded,
            hint: 'Modelo (ej. Chevrolet Spark)',
            controller: _model,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            errorText: _modelError,
            onChanged: (_) {
              if (_modelError != null) setState(() => _modelError = null);
            },
          ),
          const SizedBox(height: 12),
          RoutbField(
            icon: Icons.badge_outlined,
            hint: 'Placa (ej. ABC-123)',
            controller: _plate,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.next,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\- ]')),
              LengthLimitingTextInputFormatter(8),
            ],
            errorText: _plateError,
            onChanged: (_) {
              if (_plateError != null) setState(() => _plateError = null);
            },
          ),
          const SizedBox(height: 12),
          RoutbField(
            icon: Icons.palette_outlined,
            hint: 'Color (ej. Gris)',
            controller: _color,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            errorText: _colorError,
            onChanged: (_) {
              if (_colorError != null) setState(() => _colorError = null);
            },
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 8),
          Text(
            'El modelo, el color y la placa son obligatorios. La placa se '
            'guarda en el formato colombiano de automóvil ABC-123.',
            style: RoutbText.copy(12, color: palette.muted),
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
      footer: RoutbButton(
        label: 'Guardar vehículo',
        icon: Icons.check_rounded,
        busy: _saving,
        onPressed: _save,
      ),
    );
  }
}
