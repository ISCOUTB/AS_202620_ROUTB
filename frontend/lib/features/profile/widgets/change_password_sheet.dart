import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/routb_palette.dart';
import '../../../core/theme/routb_text.dart';
import '../../../core/widgets/routb_button.dart';
import '../../../core/widgets/routb_card.dart';
import '../../../core/widgets/routb_field.dart';
import '../../../core/widgets/routb_sheet.dart';
import '../../../core/widgets/routb_toast.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/auth_validation.dart';

/// Abre la hoja para cambiar la contraseña.
///
/// Devuelve `true` cuando el backend confirma el cambio. La verificación se
/// hace con la contraseña actual; no se agregan códigos por SMS ni
/// dependencias nuevas.
Future<bool?> showChangePasswordSheet({
  required BuildContext context,
  required AuthRepository auth,
}) {
  return showModalBottomSheet<bool>(
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
      initialChildSize: 0.72,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      builder: (context, scrollController) =>
          _ChangePasswordSheet(auth: auth, scrollController: scrollController),
    ),
  );
}

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet({
    required this.auth,
    required this.scrollController,
  });

  final AuthRepository auth;
  final ScrollController scrollController;

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final TextEditingController _current = TextEditingController();
  final TextEditingController _new = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  String? _currentError;
  String? _newError;
  String? _confirmError;
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool _validate() {
    final currentError = _current.text.isEmpty
        ? 'Ingresa tu contraseña actual'
        : null;
    final newError = validateNewPassword(_new.text);
    String? confirmError;
    if (_confirm.text.isEmpty) {
      confirmError = 'Confirma la nueva contraseña';
    } else if (_confirm.text != _new.text) {
      confirmError = 'Las contraseñas no coinciden';
    }

    setState(() {
      _currentError = currentError;
      _newError = newError;
      _confirmError = confirmError;
    });
    return currentError == null && newError == null && confirmError == null;
  }

  Future<void> _save() async {
    if (_saving || !_validate()) return;
    setState(() => _saving = true);
    try {
      await widget.auth.changePassword(
        currentPassword: _current.text,
        newPassword: _new.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error, stack) {
      logFailure('el cambio de contraseña', error, stack);
      if (!mounted) return;
      if (error.isValidation) {
        setState(() => _currentError = error.message);
      } else {
        RoutbToast.show(context, error.message);
      }
    } on Exception catch (error, stack) {
      logFailure('el cambio de contraseña', error, stack);
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
      title: 'Cambiar contraseña',
      subtitle: 'Primero confirma la contraseña que usas hoy.',
      scrollController: widget.scrollController,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const RoutbHint(
            'La nueva contraseña debe tener al menos 8 caracteres. No cierres '
            'la sesión: tus viajes y solicitudes siguen igual.',
          ),
          const SizedBox(height: 16),
          RoutbField(
            icon: Icons.lock_outline_rounded,
            hint: 'Contraseña actual',
            controller: _current,
            obscureToggle: true,
            textInputAction: TextInputAction.next,
            errorText: _currentError,
            onChanged: (_) {
              if (_currentError != null) setState(() => _currentError = null);
            },
          ),
          const SizedBox(height: 12),
          RoutbField(
            icon: Icons.lock_reset_rounded,
            hint: 'Nueva contraseña',
            controller: _new,
            obscureToggle: true,
            textInputAction: TextInputAction.next,
            errorText: _newError,
            onChanged: (_) {
              if (_newError != null) setState(() => _newError = null);
            },
          ),
          const SizedBox(height: 12),
          RoutbField(
            icon: Icons.lock_reset_rounded,
            hint: 'Confirmar nueva contraseña',
            controller: _confirm,
            obscureToggle: true,
            textInputAction: TextInputAction.done,
            errorText: _confirmError,
            onChanged: (_) {
              if (_confirmError != null) {
                setState(() => _confirmError = null);
              }
            },
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 8),
          Text(
            'Si no recuerdas tu contraseña actual, no podemos cambiarla desde '
            'aquí. Cierra sesión y vuelve a intentarlo cuando la tengas.',
            style: RoutbText.copy(12, color: palette.muted, height: 1.4),
          ),
        ],
      ),
      footer: RoutbButton(
        label: 'Guardar contraseña',
        icon: Icons.check_rounded,
        busy: _saving,
        onPressed: _save,
      ),
    );
  }
}
