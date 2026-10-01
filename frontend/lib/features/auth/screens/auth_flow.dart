import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_routes.dart';
import '../../../app/dependencies.dart';
import '../../../core/models/user_role.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/routb_motion.dart';
import '../../../core/theme/routb_palette.dart';
import '../../../core/theme/routb_text.dart';
import '../../../core/theme/routb_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/routb_button.dart';
import '../../../core/widgets/routb_card.dart';
import '../../../core/widgets/routb_field.dart';
import '../../../core/widgets/routb_logo.dart';
import '../../../core/widgets/routb_toast.dart';
import '../data/auth_repository.dart';

/// Orden de las vistas del acceso.
enum AuthStep { login, role, register }

/// Acceso de ROUTB: tres vistas encadenadas con deslizamiento lateral.
///
/// El recorrido es el del diseño —entrar, elegir perfil, crear cuenta— y el
/// botón de volver regresa a la vista anterior sin perder lo ya escrito.
///
/// Al terminar, la persona entra al modo que le corresponde sin pasar por una
/// pantalla intermedia.
class AuthFlow extends StatefulWidget {
  const AuthFlow({super.key});

  @override
  State<AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<AuthFlow> {
  final PageController _controller = PageController();

  final TextEditingController _phone = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _lastName = TextEditingController();
  final TextEditingController _registerPhone = TextEditingController();
  final TextEditingController _registerPassword = TextEditingController();

  late final List<TextEditingController> _allControllers = [
    _phone,
    _password,
    _name,
    _lastName,
    _registerPhone,
    _registerPassword,
  ];

  AuthStep _step = AuthStep.login;
  UserRole _role = UserRole.passenger;
  bool _termsAccepted = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    for (final controller in _allControllers) {
      controller.addListener(_onFieldChanged);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    for (final controller in _allControllers) {
      controller
        ..removeListener(_onFieldChanged)
        ..dispose();
    }
    super.dispose();
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  bool get _canLogin =>
      _phone.text.trim().isNotEmpty && _password.text.isNotEmpty;

  bool get _canRegister =>
      _name.text.trim().isNotEmpty &&
      _lastName.text.trim().isNotEmpty &&
      _registerPhone.text.trim().isNotEmpty &&
      _registerPassword.text.isNotEmpty &&
      _termsAccepted;

  Future<void> _goTo(AuthStep step) async {
    FocusScope.of(context).unfocus();
    setState(() => _step = step);
    await _controller.animateToPage(
      step.index,
      duration: RoutbMotion.view,
      curve: RoutbMotion.standard,
    );
  }

  Future<void> _back() async {
    if (_step == AuthStep.login) return;
    await _goTo(switch (_step) {
      AuthStep.role => AuthStep.login,
      AuthStep.register => AuthStep.role,
      AuthStep.login => AuthStep.login,
    });
  }

  Future<void> _toggleTheme() =>
      RoutbScope.of(context).toggle(Theme.of(context).brightness);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.background,
      body: PageView(
        controller: _controller,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _LoginStep(
            phone: _phone,
            password: _password,
            busy: _busy,
            canSubmit: _canLogin,
            onSubmit: _submitLogin,
            onRegister: () => _goTo(AuthStep.role),
            onToggleTheme: _toggleTheme,
          ),
          _RoleStep(
            selected: _role,
            onSelect: (role) async {
              setState(() => _role = role);
              await _goTo(AuthStep.register);
            },
            onBack: _back,
            onToggleTheme: _toggleTheme,
          ),
          _RegisterStep(
            role: _role,
            name: _name,
            lastName: _lastName,
            phone: _registerPhone,
            password: _registerPassword,
            termsAccepted: _termsAccepted,
            onTermsChanged: (value) => setState(() => _termsAccepted = value),
            canSubmit: _canRegister,
            busy: _busy,
            onSubmit: _submitRegister,
            onBack: _back,
            onToggleTheme: _toggleTheme,
          ),
        ],
      ),
    );
  }

  Future<void> _submitLogin() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final account = await RoutbScopeDependencies.of(context).auth.login(
            phone: _phone.text,
            password: _password.text,
          );
      await _enterMode(account: account, message: 'Bienvenido de vuelta');
    } on Exception catch (error, stack) {
      logFailure('el ingreso', error, stack);
      _fail(describeFailure(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitRegister() async {
    if (_busy || !_canRegister) return;
    setState(() => _busy = true);

    try {
      final account = await RoutbScopeDependencies.of(context).auth.register(
            name: _name.text,
            lastName: _lastName.text,
            phone: _registerPhone.text,
            password: _registerPassword.text,
            role: _role,
          );
      await _enterMode(
        account: account,
        message: 'Cuenta creada. ¡Bienvenido, ${account.name}!',
        delay: const Duration(milliseconds: 900),
      );
    } on Exception catch (error, stack) {
      logFailure('el registro', error, stack);
      _fail(describeFailure(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Muestra el aviso y, tras una pausa, entra al modo de la cuenta.
  Future<void> _enterMode({
    required Account account,
    required String message,
    Duration delay = const Duration(milliseconds: 700),
  }) async {
    if (!mounted) return;
    RoutbToast.show(context, message);
    await Future<void>.delayed(delay);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      RoutbFadeRoute<void>(child: ModeRoute(account: account)),
    );
  }

  void _fail(String message) {
    if (!mounted) return;
    RoutbToast.show(context, message);
  }
}

/// `.ah`: bloque de cabecera del acceso: logo, título y subtítulo.
///
/// El interruptor de tema va siempre arriba a la derecha. El logo se puede
/// centrar aunque el texto quede a la izquierda, que es como se ve en la
/// pantalla de registro.
class _AuthHeader extends StatelessWidget {
  const _AuthHeader({
    required this.title,
    required this.subtitle,
    this.onBack,
    this.trailing,
    this.alignment = CrossAxisAlignment.center,
    this.centerLogo = true,
    this.logoWidth = 118,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;
  final CrossAxisAlignment alignment;

  /// `true` centra el símbolo de ROUTB.
  final bool centerLogo;

  /// Ancho del símbolo.
  final double logoWidth;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isCentered = alignment == CrossAxisAlignment.center;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, isCentered ? 58 : 12, 24, 0),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Row(
            children: [
              if (onBack != null)
                RoutbIconButton(
                  icon: Icons.arrow_back_rounded,
                  onPressed: onBack,
                  semanticLabel: 'Volver',
                  foreground: palette.ink,
                ),
              // Empuja el interruptor de tema a la derecha aunque no haya botón
              // de volver.
              const Spacer(),
              if (trailing != null) ?trailing,
            ],
          ),
          SizedBox(height: onBack != null ? 18 : 0),
          Align(
            alignment: centerLogo ? Alignment.center : Alignment.centerLeft,
            child: RoutbLogo(
              variant: RoutbLogoVariant.onSurface.forBackground(
                context.isDarkMode,
              ),
              width: logoWidth,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: isCentered ? TextAlign.center : TextAlign.start,
            style: RoutbText.headline(28, color: palette.ink, height: 1.1),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: isCentered ? TextAlign.center : TextAlign.start,
            style: RoutbText.copy(14, color: palette.muted),
          ),
        ],
      ),
    );
  }
}

/// Primera vista: entrar con teléfono y contraseña.
class _LoginStep extends StatelessWidget {
  const _LoginStep({
    required this.phone,
    required this.password,
    required this.busy,
    required this.canSubmit,
    required this.onSubmit,
    required this.onRegister,
    required this.onToggleTheme,
  });

  final TextEditingController phone;
  final TextEditingController password;
  final bool busy;
  final bool canSubmit;
  final VoidCallback onSubmit;
  final VoidCallback onRegister;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _AuthHeader(
          title: 'Iniciar sesión',
          subtitle: 'Continúa tu viaje con ROUTB',
          trailing: _ThemeToggle(onToggle: onToggleTheme),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 26, 14, 0),
          child: RoutbCard(
            child: Column(
              children: [
                RoutbField(
                  hint: 'Número de teléfono',
                  icon: Icons.phone_rounded,
                  prefixText: '+57',
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(15),
                  ],
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                RoutbField(
                  hint: 'Contraseña',
                  icon: Icons.lock_rounded,
                  controller: password,
                  obscureToggle: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: canSubmit ? (_) => onSubmit() : null,
                ),
                const SizedBox(height: 24),
                RoutbButton(
                  label: 'Ingresar',
                  onPressed: canSubmit ? onSubmit : null,
                  busy: busy,
                ),
                const SizedBox(height: 12),
                RoutbButton(
                  label: '¿No tienes cuenta? Regístrate',
                  variant: RoutbButtonVariant.secondary,
                  onPressed: busy ? null : onRegister,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Segunda vista: elegir pasajero o conductor.
class _RoleStep extends StatelessWidget {
  const _RoleStep({
    required this.selected,
    required this.onSelect,
    required this.onBack,
    required this.onToggleTheme,
  });

  final UserRole selected;
  final ValueChanged<UserRole> onSelect;
  final VoidCallback onBack;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _AuthHeader(
          title: '¿Cómo vas a viajar?',
          subtitle: 'Elige tu perfil para continuar',
          alignment: CrossAxisAlignment.start,
          onBack: onBack,
          trailing: _ThemeToggle(onToggle: onToggleTheme),
          centerLogo: true,
          logoWidth: 84,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 26, 14, 0),
          child: Column(
            children: [
              for (final role in UserRole.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _RoleTile(
                    role: role,
                    selected: role == selected,
                    onTap: () => onSelect(role),
                  ),
                ),
            ],
          ),
        ),
        Center(
          child: Text(
            'Podrás cambiar de perfil creando otra cuenta.',
            style: RoutbText.copy(12, color: context.palette.muted),
          ),
        ),
      ],
    );
  }
}

/// `.rl`: tarjeta de perfil.
class _RoleTile extends StatelessWidget {
  const _RoleTile({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final UserRole role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final icon = role == UserRole.passenger
        ? Icons.airline_seat_recline_normal_rounded
        : Icons.directions_car_filled_rounded;

    return Semantics(
      button: true,
      selected: selected,
      label: '${role.title}. ${role.tagline}',
      child: Material(
        color: palette.card,
        borderRadius: BorderRadius.circular(RoutbTheme.radiusTile),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(RoutbTheme.radiusTile),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: role == UserRole.passenger
                        ? palette.primaryGradient
                        : palette.warmGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        role.title,
                        style: RoutbText.headline(16, color: palette.ink),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        role.tagline,
                        style: RoutbText.copy(12.5, color: palette.muted, height: 1.35),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: palette.brand, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tercera vista: crear cuenta.
class _RegisterStep extends StatelessWidget {
  const _RegisterStep({
    required this.role,
    required this.name,
    required this.lastName,
    required this.phone,
    required this.password,
    required this.termsAccepted,
    required this.onTermsChanged,
    required this.canSubmit,
    required this.busy,
    required this.onSubmit,
    required this.onBack,
    required this.onToggleTheme,
  });

  final UserRole role;
  final TextEditingController name;
  final TextEditingController lastName;
  final TextEditingController phone;
  final TextEditingController password;
  final bool termsAccepted;
  final ValueChanged<bool> onTermsChanged;
  final bool canSubmit;
  final bool busy;
  final VoidCallback onSubmit;
  final VoidCallback onBack;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _AuthHeader(
          title: 'Crear cuenta',
          subtitle: 'Únete a la comunidad universitaria de ROUTB',
          alignment: CrossAxisAlignment.start,
          onBack: onBack,
          trailing: _ThemeToggle(onToggle: onToggleTheme),
          centerLogo: true,
          logoWidth: 84,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
            child: RoutbChipLabel(label: role.registrationLabel),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 22, 14, 0),
          child: RoutbCard(
            child: Column(
              children: [
                RoutbField(
                  hint: 'Nombre',
                  icon: Icons.person_outline_rounded,
                  controller: name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                RoutbField(
                  hint: 'Apellido',
                  icon: Icons.person_outline_rounded,
                  controller: lastName,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                RoutbField(
                  hint: 'Teléfono',
                  icon: Icons.phone_rounded,
                  prefixText: '+57',
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(15),
                  ],
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                RoutbField(
                  hint: 'Contraseña',
                  icon: Icons.lock_rounded,
                  controller: password,
                  obscureToggle: true,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 18),
                RoutbCheckbox(
                  value: termsAccepted,
                  onChanged: busy ? null : onTermsChanged,
                  label: 'Acepto los términos y el uso de mis datos en la UTB',
                ),
                const SizedBox(height: 10),
                RoutbButton(
                  label: 'Crear cuenta',
                  onPressed: canSubmit ? onSubmit : null,
                  busy: busy,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Interruptor de tema para las cabeceras del acceso, sobre fondo de página.
class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle({required this.onToggle});

  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = context.isDarkMode;

    return Semantics(
      button: true,
      label: isDark ? 'Cambiar a tema claro' : 'Cambiar a tema oscuro',
      child: Material(
        color: palette.card,
        borderRadius: BorderRadius.circular(RoutbTheme.radiusControl),
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(RoutbTheme.radiusControl),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              size: 18,
              color: palette.brand,
            ),
          ),
        ),
      ),
    );
  }
}