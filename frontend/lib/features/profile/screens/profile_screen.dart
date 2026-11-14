import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

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
import '../../../core/widgets/routb_permission_status.dart';
import '../../../core/widgets/routb_section_header.dart';
import '../../../core/widgets/routb_seats.dart';
import '../../../core/widgets/routb_toast.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/screens/auth_flow.dart';
import '../widgets/vehicle_sheet.dart';
import 'edit_account_screen.dart';

/// Modos de pantalla que ofrece la pestaña de perfil, en su orden.
const List<({String label, ThemeMode mode})> _screenModes =
    <({String label, ThemeMode mode})>[
      (label: 'Claro', mode: ThemeMode.light),
      (label: 'Oscuro', mode: ThemeMode.dark),
      (label: 'Sistema', mode: ThemeMode.system),
    ];

/// Pestaña de perfil, igual para los dos modos.
///
/// Reúne la identidad, el modo de pantalla, los permisos y el cierre de sesión.
/// Las acciones de cuenta (cambiar contraseña y eliminar la cuenta) viven en la
/// hoja «Editar cuenta» para no dejar la eliminación a la vista. No tiene
/// `Scaffold` propio: vive dentro de la pantalla de cada modo, como la pestaña
/// «Mis viajes» del pasajero.
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
      RoutbScopeDependencies.of(context).profileName.value = profile.name;
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

  Future<void> _editVehicle(UserProfile profile) async {
    final updated = await showVehicleSheet(
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

    Navigator.of(context).push(
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
    return Column(
      children: [
        const RoutbSectionHeader(
          title: 'Perfil',
          subtitle: 'Tu cuenta y tus preferencias',
        ),
        Expanded(child: _body()),
      ],
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
        key: const PageStorageKey<String>('profile-tab'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          RoutbCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _IdentityHeader(profile: profile),
                const SizedBox(height: 12),
                RoutbButton(
                  label: 'Editar cuenta',
                  icon: Icons.manage_accounts_outlined,
                  variant: RoutbButtonVariant.secondary,
                  height: 44,
                  onPressed: _openEditAccount,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _screenModeCard(),
          const SizedBox(height: 14),
          const _PermissionsCard(),
          if (profile.role == UserRole.driver) ...[
            const SizedBox(height: 14),
            _vehicleCard(profile),
          ],
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
            icon: Icons.directions_car_filled_rounded,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        profile.vehicleLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RoutbText.headline(15, color: palette.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Visible solo para pasajeros con cupo confirmado',
                        maxLines: 2,
                        style: RoutbText.copy(12, color: palette.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: RoutbTextAction(
                label: 'Editar vehículo',
                icon: Icons.edit_outlined,
                onPressed: () => _editVehicle(profile),
              ),
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
    final palette = context.palette;
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
          const SizedBox(height: 10),
          Text(
            'Los permisos se piden solo cuando usas la función que los '
            'necesita. Si los desactivas, puedes volver a activarlos aquí.',
            style: RoutbText.copy(12, color: palette.muted, height: 1.4),
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
          size: 64,
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
            ],
          ),
        ),
        const SizedBox(width: 8),
        RoutbChipLabel(label: profile.roleLabel),
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
