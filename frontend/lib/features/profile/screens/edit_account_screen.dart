import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/routb_palette.dart';
import '../../../core/theme/routb_text.dart';
import '../../../core/theme/routb_theme.dart';
import '../../../core/widgets/routb_button.dart';
import '../../../core/widgets/routb_card.dart';
import '../../../core/widgets/routb_seats.dart';
import '../../../core/widgets/routb_toast.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/screens/auth_flow.dart';
import '../widgets/change_password_sheet.dart';
import '../widgets/edit_profile_sheet.dart';

/// Pantalla independiente para editar los datos y la seguridad de la cuenta.
///
/// Agrupa las acciones en tres bloques: datos personales, seguridad y
/// eliminación. El perfil que la abre recibe los cambios con
/// [onProfileUpdated] para no quedar con el nombre o el teléfono viejos.
class EditAccountScreen extends StatefulWidget {
  const EditAccountScreen({
    required this.profile,
    required this.auth,
    required this.onProfileUpdated,
    super.key,
  });

  /// Perfil vigente al abrir la pantalla.
  final UserProfile profile;

  /// Repositorio de autenticación que ejecuta los cambios.
  final AuthRepository auth;

  /// Avisa al perfil cuando se guardan datos personales nuevos.
  final ValueChanged<UserProfile> onProfileUpdated;

  @override
  State<EditAccountScreen> createState() => _EditAccountScreenState();
}

class _EditAccountScreenState extends State<EditAccountScreen> {
  late UserProfile _profile = widget.profile;
  bool _deleting = false;

  Future<void> _editPersonalData() async {
    final updated = await showEditProfileSheet(
      context: context,
      profile: _profile,
      auth: widget.auth,
    );
    if (updated == null || !mounted) return;
    setState(() => _profile = updated);
    widget.onProfileUpdated(updated);
    RoutbToast.show(context, 'Datos personales actualizados');
  }

  Future<void> _changePassword() async {
    final changed = await showChangePasswordSheet(
      context: context,
      auth: widget.auth,
    );
    if (changed != true || !mounted) return;
    RoutbToast.show(context, 'Contraseña actualizada');
  }

  Future<void> _deleteAccount() async {
    if (_deleting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final palette = dialogContext.palette;
        return AlertDialog(
          title: const Text('¿Eliminar tu cuenta?'),
          content: const Text(
            'Se borrarán tu perfil, tus datos de vehículo y tus solicitudes. '
            'Esta acción no se puede deshacer.\n\n'
            'Si tienes una ruta activa o una solicitud pendiente, cancélala '
            'antes de continuar.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Mantener cuenta'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                'Eliminar cuenta',
                style: TextStyle(color: palette.rose),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await widget.auth.deleteAccount();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        RoutbPageRoute<void>(child: const AuthFlow()),
        (route) => false,
      );
      RoutbToast.show(context, 'Tu cuenta fue eliminada');
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _deleting = false);
      RoutbToast.show(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(title: const Text('Editar cuenta')),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: RoutbTheme.contentMaxWidth,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
              children: [
                _PersonalDataCard(profile: _profile, onEdit: _editPersonalData),
                const SizedBox(height: 14),
                _SecurityCard(onChangePassword: _changePassword),
                const SizedBox(height: 14),
                _DeleteAccountCard(busy: _deleting, onDelete: _deleteAccount),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bloque con la identidad actual y el acceso a la edición de datos.
class _PersonalDataCard extends StatelessWidget {
  const _PersonalDataCard({required this.profile, required this.onEdit});

  final UserProfile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return RoutbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const RoutbCardHeader(
            title: 'Datos personales',
            icon: Icons.badge_outlined,
          ),
          Row(
            children: [
              InitialsAvatar(
                name: profile.fullName,
                initials: profile.initials,
                size: 52,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      profile.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RoutbText.headline(17, color: palette.ink),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      profile.phone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RoutbText.copy(13, color: palette.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          RoutbButton(
            label: 'Editar datos personales',
            icon: Icons.edit_outlined,
            variant: RoutbButtonVariant.secondary,
            height: 44,
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}

/// Bloque de seguridad con el cambio de contraseña.
class _SecurityCard extends StatelessWidget {
  const _SecurityCard({required this.onChangePassword});

  final VoidCallback onChangePassword;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return RoutbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const RoutbCardHeader(
            title: 'Seguridad',
            icon: Icons.lock_outline_rounded,
          ),
          Text(
            'Cambia tu contraseña cuando lo necesites. Te pediremos la actual '
            'para confirmar el cambio.',
            style: RoutbText.copy(12.5, color: palette.muted, height: 1.4),
          ),
          const SizedBox(height: 14),
          RoutbButton(
            label: 'Cambiar contraseña',
            icon: Icons.password_rounded,
            variant: RoutbButtonVariant.secondary,
            height: 44,
            onPressed: onChangePassword,
          ),
        ],
      ),
    );
  }
}

/// Bloque de eliminación, separado para que no quede a la vista por accidente.
class _DeleteAccountCard extends StatelessWidget {
  const _DeleteAccountCard({required this.busy, required this.onDelete});

  final bool busy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return RoutbCard(
      borderColor: palette.rose.withValues(alpha: 0.45),
      borderWidth: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const RoutbCardHeader(
            title: 'Eliminar cuenta',
            icon: Icons.warning_amber_rounded,
          ),
          Text(
            'Se borrarán tu perfil, tus datos de vehículo y tus solicitudes. '
            'Esta acción no se puede deshacer.',
            style: RoutbText.copy(12.5, color: palette.muted, height: 1.4),
          ),
          const SizedBox(height: 14),
          RoutbButton(
            label: 'Eliminar mi cuenta',
            icon: Icons.delete_forever_outlined,
            variant: RoutbButtonVariant.danger,
            busy: busy,
            onPressed: busy ? null : onDelete,
          ),
        ],
      ),
    );
  }
}
