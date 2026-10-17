import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/dependencies.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/models/user_role.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/routb_palette.dart';
import '../../../core/theme/routb_text.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/routb_button.dart';
import '../../../core/widgets/routb_card.dart';
import '../../../core/widgets/routb_field.dart';
import '../../../core/widgets/routb_hero.dart';
import '../../../core/widgets/routb_seats.dart';
import '../../../core/widgets/routb_toast.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/screens/auth_flow.dart';

/// Modos de pantalla que ofrece la pestaña de perfil, en su orden.
const List<({String label, ThemeMode mode})> _screenModes =
    <({String label, ThemeMode mode})>[
      (label: 'Claro', mode: ThemeMode.light),
      (label: 'Oscuro', mode: ThemeMode.dark),
      (label: 'Sistema', mode: ThemeMode.system),
    ];

/// Pestaña de perfil, igual para los dos modos.
///
/// Reúne los datos de la cuenta, el modo de pantalla, la autorización de
/// ubicación y el cierre de sesión. No tiene `Scaffold` propio: vive dentro de
/// la pantalla de cada modo, como la pestaña «Mis viajes» del pasajero.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({required this.account, super.key});

  /// Cuenta con la que se entró; el saludo del hero sale de aquí.
  final Account account;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile;
  String? _error;
  bool _loading = true;
  bool _changingConsent = false;
  bool _asked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // La primera carga se pide desde aquí y no desde `initState`: el
    // repositorio sale del scope de dependencias, que no se puede leer mientras
    // `initState` corre.
    if (_asked) return;
    _asked = true;
    _load();
  }

  AuthRepository get _auth => RoutbScopeDependencies.of(context).auth;

  /// Carga inicial o reintento: muestra el estado de carga.
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await _auth.fetchProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } on Exception catch (error, stack) {
      logFailure('la carga del perfil', error, stack);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = describeFailure(error);
      });
    }
  }

  /// Relee el perfil sin sustituir lo que ya se ve, para «deslizar para
  /// actualizar».
  Future<void> _refresh() async {
    try {
      final profile = await _auth.fetchProfile();
      if (mounted) setState(() => _profile = profile);
    } on Exception catch (error, stack) {
      logFailure('la actualización del perfil', error, stack);
      if (mounted) RoutbToast.show(context, describeFailure(error));
    }
  }

  Future<void> _grantConsent() => _changeConsent(grant: true);

  Future<void> _revokeConsent() async {
    if (!await _confirmRevoke()) return;
    await _changeConsent(grant: false);
  }

  Future<void> _changeConsent({required bool grant}) async {
    final dependencies = RoutbScopeDependencies.of(context);
    setState(() => _changingConsent = true);
    try {
      if (grant) {
        await dependencies.auth.grantLocationConsent();
      } else {
        await dependencies.auth.revokeLocationConsent();
      }
      if (!mounted) return;
      // El endpoint confirmó el cambio: se refleja al instante, sin depender
      // de volver a leer el perfil (que puede no informar el campo si el
      // backend todavía no está actualizado).
      setState(() {
        _profile = _profile?.withLocationConsent(grant ? DateTime.now() : null);
      });
      // Al revocar, el backend cancela las solicitudes pendientes: las pestañas
      // de viajes deben releer su estado.
      dependencies.requestRefresh.value++;
      RoutbToast.show(
        context,
        grant ? 'Ubicación autorizada' : 'Autorización revocada',
      );
    } on Exception catch (error, stack) {
      logFailure('el cambio de autorización de ubicación', error, stack);
      if (mounted) RoutbToast.show(context, describeFailure(error));
    } finally {
      if (mounted) setState(() => _changingConsent = false);
    }
  }

  Future<bool> _confirmRevoke() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Revocar la ubicación?'),
        content: const Text(
          'Se cancelan tus solicitudes pendientes y se borran las ubicaciones '
          'guardadas. Después no podrás buscar direcciones ni publicar o pedir '
          'viajes que necesiten coordenadas exactas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Mantener'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Revocar',
              style: TextStyle(color: dialogContext.palette.rose),
            ),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _logout() async {
    final dependencies = RoutbScopeDependencies.of(context);
    await dependencies.push.logout();
    await dependencies.auth.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      RoutbPageRoute<void>(child: const AuthFlow()),
      (route) => false,
    );
    RoutbToast.show(context, 'Cerraste sesión');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _hero(),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _hero() {
    final palette = context.palette;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: palette.heroGradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HeroBar(
            role: widget.account.role,
            userName: widget.account.name,
            onLogout: _logout,
            isDarkBackground: true,
            wave: widget.account.role == UserRole.passenger,
          ),
          const SizedBox(height: 8),
          Text('Perfil', style: RoutbText.headline(22, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const _ProfileLoading();

    final error = _error;
    if (error != null) return _ProfileFailed(message: error, onRetry: _load);

    final profile = _profile!;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          RoutbCard(child: _IdentityHeader(profile: profile)),
          const SizedBox(height: 14),
          _screenModeCard(),
          const SizedBox(height: 14),
          _locationCard(profile),
          const SizedBox(height: 14),
          const RoutbHint(
            'La edición de tus datos y el cambio de contraseña llegarán en una '
            'próxima versión.',
          ),
          const SizedBox(height: 18),
          RoutbButton(
            label: 'Cerrar sesión',
            icon: Icons.logout_rounded,
            variant: RoutbButtonVariant.secondary,
            onPressed: _logout,
          ),
        ],
      ),
    );
  }

  Widget _screenModeCard() {
    final controller = RoutbScope.of(context);
    return RoutbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const RoutbCardHeader(
            title: 'Modo de pantalla',
            icon: Icons.brightness_6_rounded,
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in _screenModes)
                RoutbChip(
                  label: option.label,
                  selected: controller.mode == option.mode,
                  onTap: () => controller.setMode(option.mode),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _locationCard(UserProfile profile) {
    final palette = context.palette;
    final hasConsent = profile.hasLocationConsent;
    return RoutbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const RoutbCardHeader(
            title: 'Ubicación',
            icon: Icons.location_on_outlined,
          ),
          Text(
            profile.consentLabel,
            style: RoutbText.copy(
              14,
              color: palette.ink,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasConsent
                ? 'Sirve para buscar direcciones y ver sugerencias puerta a '
                      'puerta. Puedes revocarla cuando quieras.'
                : 'Sin esta autorización no puedes buscar direcciones ni ver '
                      'sugerencias puerta a puerta.',
            style: RoutbText.copy(12, color: palette.muted),
          ),
          const SizedBox(height: 14),
          if (hasConsent)
            RoutbTextAction(
              label: 'Revocar autorización',
              color: palette.rose,
              onPressed: _changingConsent ? null : _revokeConsent,
            )
          else
            RoutbButton(
              label: 'Autorizar ubicación',
              busy: _changingConsent,
              onPressed: _grantConsent,
            ),
        ],
      ),
    );
  }
}

/// Avatar, nombre, teléfono y rol de la cuenta.
class _IdentityHeader extends StatelessWidget {
  const _IdentityHeader({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      children: [
        InitialsAvatar(
          name: profile.fullName,
          initials: profile.initials,
          size: 54,
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
                style: RoutbText.headline(18, color: palette.ink),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.phone_rounded, size: 13, color: palette.muted),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      profile.phone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RoutbText.copy(13, color: palette.muted),
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: RoutbChipLabel(label: profile.roleLabel),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileLoading extends StatelessWidget {
  const _ProfileLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 24),
      children: const [
        RoutbSkeleton(height: 110),
        SizedBox(height: 14),
        RoutbSkeleton(height: 150),
      ],
    );
  }
}

class _ProfileFailed extends StatelessWidget {
  const _ProfileFailed({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 60, 14, 24),
      children: [
        RoutbEmptyState(
          icon: Icons.cloud_off_rounded,
          message: message,
          action: RoutbButton(
            label: 'Reintentar',
            icon: Icons.refresh_rounded,
            variant: RoutbButtonVariant.secondary,
            expand: false,
            height: 44,
            onPressed: onRetry,
          ),
        ),
      ],
    );
  }
}
