import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/routb_button.dart';
import '../../../core/widgets/routb_card.dart';
import '../../../core/widgets/routb_field.dart';
import '../../../core/widgets/route_actions.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/auth_validation.dart';
import '../widgets/profile_form_page.dart';

/// Abre la pantalla para cambiar la contraseña.
///
/// Devuelve `true` cuando el backend confirma el cambio. La verificación se
/// hace con la contraseña actual; no se agregan códigos por SMS ni
/// dependencias nuevas.
Future<bool?> openChangePasswordScreen({
  required BuildContext context,
  required AuthRepository auth,
}) => context.pushFromCurrent(
  RoutbPageRoute<bool>(child: _ChangePasswordScreen(auth: auth)),
);

class _ChangePasswordScreen extends StatefulWidget {
  const _ChangePasswordScreen({required this.auth});

  final AuthRepository auth;

  @override
  State<_ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<_ChangePasswordScreen> {
  final TextEditingController _current = TextEditingController();
  final TextEditingController _new = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  final _currentFocus = FocusNode();
  String? _currentError;
  String? _newError;
  String? _confirmError;
  bool _saving = false;
  String? _saveError;

  @override
  void dispose() {
    _currentFocus.dispose();
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
    setState(() {
      _saving = true;
      _saveError = null;
    });
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
      if (error.statusCode == 400) {
        setState(() => _currentError = error.message);
        _currentFocus.requestFocus();
      } else {
        setState(() => _saveError = error.message);
      }
    } on Exception catch (error, stack) {
      logFailure('el cambio de contraseña', error, stack);
      if (!mounted) return;
      setState(() => _saveError = describeFailure(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProfileFormPage(
      busy: _saving,
      title: 'Cambiar contraseña',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const RoutbHint(
            'La nueva contraseña debe tener al menos 8 caracteres.',
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          ),
          const SizedBox(height: 16),
          RoutbField(
            icon: Icons.lock_outline_rounded,
            hint: 'Contraseña actual',
            controller: _current,
            focusNode: _currentFocus,
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
        ],
      ),
      footer: RoutbFormFooter(
        error: _saveError,
        action: RoutbButton(
          label: 'Guardar contraseña',
          icon: Icons.check_rounded,
          busy: _saving,
          onPressed: _save,
        ),
      ),
    );
  }
}
