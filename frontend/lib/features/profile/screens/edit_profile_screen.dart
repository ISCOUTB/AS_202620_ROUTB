import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_routes.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/routb_palette.dart';
import '../../../core/theme/routb_text.dart';
import '../../../core/widgets/routb_button.dart';
import '../../../core/widgets/routb_card.dart';
import '../../../core/widgets/routb_field.dart';
import '../../../core/widgets/route_actions.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/auth_validation.dart';
import '../widgets/profile_form_page.dart';

/// Abre la pantalla para editar nombre, apellido y teléfono.
///
/// Devuelve el perfil actualizado cuando el backend confirma el cambio, o
/// `null` si se cerró sin guardar. El teléfono es también el usuario de
/// ingreso, así que el backend valida que siga siendo único.
Future<UserProfile?> openEditProfileScreen({
  required BuildContext context,
  required UserProfile profile,
  required AuthRepository auth,
}) => context.pushFromCurrent(
  RoutbPageRoute<UserProfile>(
    child: _EditProfileScreen(profile: profile, auth: auth),
  ),
);

class _EditProfileScreen extends StatefulWidget {
  const _EditProfileScreen({required this.profile, required this.auth});

  final UserProfile profile;
  final AuthRepository auth;

  @override
  State<_EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<_EditProfileScreen> {
  late final TextEditingController _name = TextEditingController(
    text: widget.profile.name,
  );
  late final TextEditingController _lastName = TextEditingController(
    text: widget.profile.lastName,
  );
  late final TextEditingController _phone = TextEditingController(
    text: widget.profile.phone,
  );

  String? _nameError;
  String? _lastNameError;
  String? _phoneError;
  bool _saving = false;
  String? _saveError;

  @override
  void dispose() {
    _name.dispose();
    _lastName.dispose();
    _phone.dispose();
    super.dispose();
  }

  bool _validate() {
    final nameError = validateName(_name.text, 'nombre');
    final lastNameError = validateName(_lastName.text, 'apellido');
    final phoneError = validatePhone(_phone.text);
    final normalizedPhone = normalizePhone(_phone.text);

    setState(() {
      _nameError = nameError;
      _lastNameError = lastNameError;
      _phoneError =
          phoneError ?? (normalizedPhone == null ? 'Teléfono inválido' : null);
    });
    return nameError == null &&
        lastNameError == null &&
        phoneError == null &&
        normalizedPhone != null;
  }

  Future<void> _save() async {
    if (_saving || !_validate()) return;
    final phone = normalizePhone(_phone.text);
    if (phone == null) return;

    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final updated = await widget.auth.updateProfile(
        name: _name.text,
        lastName: _lastName.text,
        phone: phone,
      );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.isConflict) {
        setState(() => _phoneError = 'Este teléfono ya está registrado.');
      } else {
        setState(() => _saveError = error.message);
      }
    } on Exception catch (error, stack) {
      logFailure('la edición del perfil', error, stack);
      if (!mounted) return;
      setState(() => _saveError = describeFailure(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ProfileFormPage(
      busy: _saving,
      title: 'Editar datos personales',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const RoutbHint(
            'Tu teléfono es también el usuario con el que ingresas. Si lo '
            'cambias, deberás usar el nuevo la próxima vez.',
          ),
          const SizedBox(height: 16),
          RoutbField(
            icon: Icons.person_outline_rounded,
            hint: 'Nombre',
            controller: _name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            errorText: _nameError,
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
          ),
          const SizedBox(height: 12),
          RoutbField(
            icon: Icons.person_outline_rounded,
            hint: 'Apellido',
            controller: _lastName,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            errorText: _lastNameError,
            onChanged: (_) {
              if (_lastNameError != null) setState(() => _lastNameError = null);
            },
          ),
          const SizedBox(height: 12),
          RoutbField(
            icon: Icons.phone_rounded,
            hint: 'Teléfono',
            prefixText: '+57',
            controller: _phone,
            keyboardType: TextInputType.phone,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(15),
            ],
            textInputAction: TextInputAction.done,
            errorText: _phoneError,
            onChanged: (_) {
              if (_phoneError != null) setState(() => _phoneError = null);
            },
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 8),
          Text(
            'El nombre y el apellido aparecen en tus viajes. El teléfono solo '
            'se comparte cuando hay un cupo confirmado.',
            style: RoutbText.copy(12, color: palette.muted, height: 1.4),
          ),
        ],
      ),
      footer: RoutbFormFooter(
        error: _saveError,
        action: RoutbButton(
          label: 'Guardar cambios',
          icon: Icons.check_rounded,
          busy: _saving,
          onPressed: _save,
        ),
      ),
    );
  }
}
