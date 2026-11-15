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
import '../../auth/data/auth_validation.dart';

/// Abre la hoja para editar nombre, apellido y teléfono.
///
/// Devuelve el perfil actualizado cuando el backend confirma el cambio, o
/// `null` si se cerró sin guardar. El teléfono es también el usuario de
/// ingreso, así que el backend valida que siga siendo único.
Future<UserProfile?> showEditProfileSheet({
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
      initialChildSize: 0.72,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      builder: (context, scrollController) => _EditProfileSheet(
        profile: profile,
        auth: auth,
        scrollController: scrollController,
      ),
    ),
  );
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({
    required this.profile,
    required this.auth,
    required this.scrollController,
  });

  final UserProfile profile;
  final AuthRepository auth;
  final ScrollController scrollController;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
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

    setState(() => _saving = true);
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
      RoutbToast.show(context, error.message);
    } on Exception catch (error, stack) {
      logFailure('la edición del perfil', error, stack);
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
      title: 'Editar perfil',
      subtitle: 'Actualiza cómo te ven los demás en ROUTB.',
      scrollController: widget.scrollController,
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
      footer: RoutbButton(
        label: 'Guardar cambios',
        icon: Icons.check_rounded,
        busy: _saving,
        onPressed: _save,
      ),
    );
  }
}
