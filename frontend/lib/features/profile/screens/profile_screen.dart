import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/route_actions.dart';

import 'package:geolocator/geolocator.dart';

import '../../../app/app_routes.dart';
import '../../../app/dependencies.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/models/user_role.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/routb_palette.dart';
import '../../../core/theme/routb_text.dart';
import '../../../core/theme/routb_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/routb_button.dart';
import '../../../core/widgets/routb_card.dart';
import '../../../core/widgets/routb_field.dart';
import '../../../core/widgets/routb_permission_status.dart';
import '../../../core/widgets/routb_section_header.dart';
import '../../../core/widgets/routb_seats.dart';
import '../../../core/widgets/routb_steering_wheel.dart';
import '../../../core/widgets/routb_toast.dart';
import '../../../core/widgets/travel_mode_selector.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/screens/auth_flow.dart';
import 'vehicle_screen.dart';
import 'edit_account_screen.dart';

/// Modos de pantalla que ofrece la pestaña de perfil, en su orden.
const List<({String label, String description, IconData icon, ThemeMode mode})>
_screenModes =
    <({String label, String description, IconData icon, ThemeMode mode})>[
      (
        label: 'Claro',
        description: 'Mejor visibilidad en ambientes muy iluminados.',
        icon: Icons.light_mode_rounded,
        mode: ThemeMode.light,
      ),
      (
        label: 'Oscuro',
        description: 'Más cómodo para la vista y ahorra batería.',
        icon: Icons.dark_mode_rounded,
        mode: ThemeMode.dark,
      ),
      (
        label: 'Predeterminado del sistema',
        description: 'Sigue el modo claro u oscuro configurado en el teléfono.',
        icon: Icons.brightness_auto_rounded,
        mode: ThemeMode.system,
      ),
    ];

/// Pestaña de perfil, igual para los dos modos.
///
/// Reúne la identidad, el modo de pantalla, los permisos y el cierre de sesión.
/// Las acciones de cuenta (cambiar contraseña y eliminar la cuenta) viven en la
/// hoja «Editar cuenta» para no dejar la eliminación a la vista. No tiene
/// `Scaffold` propio: vive dentro de la pantalla de cada modo, como la pestaña
/// «Mis viajes» del pasajero.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({required this.account, this.onProfileLoaded, super.key});

  /// Cuenta con la que se entró; el saludo del hero sale de aquí.
  final Account account;

  /// Notifica cuando el perfil fresco se termina de cargar.
  final ValueChanged<UserProfile>? onProfileLoaded;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late UserProfile? _profile = widget.account.profile;
  String? _error;
  late bool _loading = _profile == null;
  bool _asked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // La primera carga se pide desde aquí y no desde `initState`: el
    // repositorio sale del scope de dependencias, que no se puede leer mientras
    // `initState` corre.
    if (_asked) return;
    _asked = true;
    if (_profile == null) _load();
  }

  @override
  void didUpdateWidget(ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final profile = widget.account.profile;
    if (profile != null && !identical(profile, oldWidget.account.profile)) {
      _profile = profile;
      _loading = false;
      _error = null;
    }
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
      RoutbScopeDependencies.of(context).profileName.value = profile.name;
      setState(() {
        _profile = profile;
        _loading = false;
      });
      widget.onProfileLoaded?.call(profile);
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

  Future<void> _editVehicle(UserProfile profile) async {
    final updated = await openVehicleScreen(
      context: context,
      profile: profile,
      auth: _auth,
    );
    if (updated == null || !mounted) return;
    setState(() => _profile = updated);
    RoutbToast.show(
      context,
      updated.hasCompleteVehicle
          ? 'Vehículo actualizado'
          : updated.hasVehicle
          ? 'El vehículo quedó incompleto'
          : 'Vehículo retirado',
    );
  }

  void _openEditAccount() {
    final profile = _profile;
    if (profile == null) return;

    context.pushFromCurrent(
      RoutbPageRoute<void>(
        child: EditAccountScreen(
          profile: profile,
          auth: _auth,
          onProfileUpdated: (updated) {
            if (!mounted) return;
            setState(() => _profile = updated);
            RoutbScopeDependencies.of(context).profileName.value = updated.name;
          },
        ),
      ),
    );
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
    return RoutbSectionPage(
      title: 'Perfil',
      subtitle: 'Tu cuenta y tus preferencias',
      icon: Icons.person_outline_rounded,
      primary: _loading || _error != null || _profile == null
          ? null
          : _identityCard(_profile!),
      body: _body,
    );
  }

  Widget _body(bool split) {
    final error = _error;
    if (error != null) {
      return _ProfileFailed(message: error, onRetry: _load, onLogout: _logout);
    }

    final profile = _profile;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        key: const PageStorageKey<String>('profile-tab'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          if (profile == null && _loading) ...[
            Text(
              widget.account.name,
              style: RoutbText.headline(22, color: context.palette.ink),
            ),
            const SizedBox(height: 14),
          ],
          if (profile != null && !split) ...[
            _identityCard(profile),
            const SizedBox(height: 14),
          ],
          if (profile != null && widget.account.role == UserRole.driver) ...[
            _vehicleCard(profile),
            const SizedBox(height: 14),
          ],
          _screenModeCard(),
          const SizedBox(height: 14),
          const _PermissionsCard(),
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

  Widget _identityCard(UserProfile profile) => RoutbCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _IdentityHeader(profile: profile),
        const SizedBox(height: 12),
        RoutbButton(
          label: 'Editar cuenta',
          icon: Icons.manage_accounts_outlined,
          height: 44,
          onPressed: _openEditAccount,
        ),
      ],
    ),
  );

  Widget _screenModeCard() {
    final controller = RoutbScope.maybeOf(context);
    if (controller == null) return const SizedBox.shrink();
    return RoutbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const RoutbCardHeader(
            title: 'Modo de pantalla',
            icon: Icons.brightness_6_rounded,
          ),
          for (final (index, option) in _screenModes.indexed) ...[
            if (index > 0) const Divider(height: 1),
            _ScreenModeOption(
              label: option.label,
              description: option.description,
              icon: option.icon,
              selected: controller.mode == option.mode,
              onTap: () => controller.setMode(option.mode),
            ),
          ],
        ],
      ),
    );
  }

  Widget _vehicleCard(UserProfile profile) {
    final palette = context.palette;
    final hasVehicle = profile.hasVehicle;
    final complete = profile.hasCompleteVehicle;
    final missing = profile.missingVehicleFields;

    return RoutbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RoutbCardHeader(
            title: 'Vehículo',
            leading: RoutbSteeringWheelIcon(color: palette.brand),
            trailing: RoutbStatusPill(
              label: complete
                  ? 'Registrado'
                  : hasVehicle
                  ? 'Pendiente'
                  : 'Sin registrar',
              background: complete ? palette.mintSurface : palette.amberSurface,
              foreground: complete
                  ? palette.onMintSurface
                  : palette.onAmberSurface,
            ),
          ),
          if (complete) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: palette.brandSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.directions_car_filled_rounded,
                    size: 19,
                    color: palette.brand,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    profile.vehicleLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RoutbText.headline(15, color: palette.ink),
                  ),
                ),
                const SizedBox(width: 8),
                RoutbTextAction(
                  label: 'Editar vehículo',
                  icon: Icons.edit_outlined,
                  onPressed: () => _editVehicle(profile),
                ),
              ],
            ),
          ] else ...[
            Text(
              hasVehicle
                  ? 'Falta completar: ${missing.join(', ')}. Sin los tres datos '
                        'no podrás publicar rutas.'
                  : 'Registra el modelo, el color y la placa para que tus '
                        'pasajeros reconozcan el carro al llegar al punto de '
                        'encuentro.',
              style: RoutbText.copy(12.5, color: palette.muted, height: 1.4),
            ),
            const SizedBox(height: 14),
            RoutbButton(
              label: hasVehicle ? 'Completar vehículo' : 'Registrar vehículo',
              icon: hasVehicle ? Icons.edit_outlined : Icons.add_rounded,
              variant: RoutbButtonVariant.secondary,
              height: 44,
              onPressed: () => _editVehicle(profile),
            ),
          ],
        ],
      ),
    );
  }
}

/// Opción vertical del modo de pantalla, con su descripción y marca de
/// selección.
class _ScreenModeOption extends StatelessWidget {
  const _ScreenModeOption({
    required this.label,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  /// Nombre del modo.
  final String label;

  /// Explicación breve de lo que aporta el modo.
  final String description;

  /// Icono representativo del modo.
  final IconData icon;

  /// `true` si es el modo activo.
  final bool selected;

  /// Acción al pulsar.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Semantics(
      button: true,
      selected: selected,
      label: '$label. $description',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(RoutbTheme.radiusControl),
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              color: selected ? palette.brandSurface : palette.card,
              borderRadius: BorderRadius.circular(RoutbTheme.radiusControl),
              border: Border.all(
                color: selected ? palette.onBrandSurface : palette.card,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: selected ? palette.brand : palette.brandSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 19,
                    color: selected ? palette.onBrand : palette.brand,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: RoutbText.headline(14.5, color: palette.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: RoutbText.copy(
                          12,
                          color: palette.muted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 20,
                  color: selected ? palette.brand : palette.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Estado de los permisos del sistema que ROUTB usa (G20).
///
/// Solo consulta y muestra; si están denegados ofrece abrir los ajustes del
/// celular. No pide permisos al iniciar la app: cada función los solicita
/// cuando de verdad los necesita.
class _PermissionsCard extends StatefulWidget {
  const _PermissionsCard();

  @override
  State<_PermissionsCard> createState() => _PermissionsCardState();
}

class _PermissionsCardState extends State<_PermissionsCard> {
  RoutbPermissionState _location = RoutbPermissionState.loading;
  RoutbPermissionState _notifications = RoutbPermissionState.loading;
  bool _asked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_asked) return;
    _asked = true;
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _locationStatus(),
      _notificationStatus(),
    ]);
    if (!mounted) return;
    setState(() {
      _location = results[0];
      _notifications = results[1];
    });
  }

  Future<RoutbPermissionState> _locationStatus() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return RoutbPermissionState.denied;
      }
      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.always ||
              permission == LocationPermission.whileInUse
          ? RoutbPermissionState.granted
          : RoutbPermissionState.denied;
    } on Object {
      return RoutbPermissionState.denied;
    }
  }

  Future<RoutbPermissionState> _notificationStatus() async {
    try {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      return switch (settings.authorizationStatus) {
        AuthorizationStatus.authorized ||
        AuthorizationStatus.provisional => RoutbPermissionState.granted,
        _ => RoutbPermissionState.denied,
      };
    } on Object {
      return RoutbPermissionState.denied;
    }
  }

  Future<void> _openSettings() async {
    try {
      await Geolocator.openAppSettings();
    } on Object {
      // Sin ajustes disponibles en esta plataforma: la app no se bloquea.
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return RoutbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const RoutbCardHeader(
            title: 'Permisos',
            icon: Icons.verified_user_outlined,
          ),
          RoutbPermissionStatus(
            title: 'Ubicación',
            description: 'Para buscar direcciones y ver sugerencias cercanas.',
            icon: Icons.location_on_outlined,
            state: _location,
            onOpenSettings: _openSettings,
          ),
          const SizedBox(height: 4),
          RoutbPermissionStatus(
            title: 'Notificaciones',
            description: 'Para avisarte cuando una solicitud cambie de estado.',
            icon: Icons.notifications_none_rounded,
            state: _notifications,
            onOpenSettings: _openSettings,
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
          size: 52,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                TravelModeScope.maybeOf(context)?.mode.label ??
                    profile.roleLabel,
                style: RoutbText.copy(
                  12,
                  color: palette.onBrandSurface,
                  weight: FontWeight.w700,
                ),
              ),
              Text(
                profile.fullName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: RoutbText.headline(22, color: palette.ink),
              ),
              Text(
                profile.phone,
                style: RoutbText.copy(13, color: palette.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileFailed extends StatelessWidget {
  const _ProfileFailed({
    required this.message,
    required this.onRetry,
    required this.onLogout,
  });
  final VoidCallback onLogout;

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
        RoutbButton(
          label: 'Cerrar sesión',
          icon: Icons.logout_rounded,
          variant: RoutbButtonVariant.secondary,
          onPressed: onLogout,
        ),
      ],
    );
  }
}
