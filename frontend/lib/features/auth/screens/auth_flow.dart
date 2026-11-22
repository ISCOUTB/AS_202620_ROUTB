import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_routes.dart';
import '../../../app/dependencies.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/routb_motion.dart';
import '../../../core/theme/routb_palette.dart';
import '../../../core/theme/routb_text.dart';
import '../../../core/widgets/routb_button.dart';
import '../../../core/widgets/routb_card.dart';
import '../../../core/widgets/routb_field.dart';
import '../../../core/widgets/routb_logo.dart';
import '../../../core/widgets/routb_toast.dart';
import '../data/auth_repository.dart';
import '../data/auth_validation.dart';

/// Orden de las vistas del acceso.
enum AuthStep { login, register }

/// Acceso y registro con navegación de regreso al ingreso.
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
      validatePhone(_phone.text) == null && _password.text.isNotEmpty;

  bool get _canRegister =>
      validateName(_name.text, 'nombre') == null &&
      validateName(_lastName.text, 'apellido') == null &&
      validatePhone(_registerPhone.text) == null &&
      validateNewPassword(_registerPassword.text) == null &&
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
    await _goTo(AuthStep.login);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return PopScope<void>(
      canPop: _step == AuthStep.login,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: palette.background,
        body: SafeArea(
          child: PageView(
            controller: _controller,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _LoginStep(
                phone: _phone,
                password: _password,
                busy: _busy,
                canSubmit: _canLogin,
                onSubmit: _submitLogin,
                onRegister: () => _goTo(AuthStep.register),
              ),
              _RegisterStep(
                name: _name,
                lastName: _lastName,
                phone: _registerPhone,
                password: _registerPassword,
                termsAccepted: _termsAccepted,
                onTermsChanged: (value) =>
                    setState(() => _termsAccepted = value),
                canSubmit: _canRegister,
                busy: _busy,
                onSubmit: _submitRegister,
                onBack: _back,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitLogin() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final account = await RoutbScopeDependencies.of(context).auth
          .login(phone: _phone.text, password: _password.text);
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
    Navigator.of(
      context,
    ).pushReplacement(RoutbFadeRoute<void>(child: ModeRoute(account: account)));
  }

  void _fail(String message) {
    if (!mounted) return;
    RoutbToast.show(context, message);
  }
}

/// `.ah`: bloque de cabecera del acceso: marca, título y subtítulo.
///
/// La marca se centra aunque el texto quede a la izquierda en el registro.
class _AuthHeader extends StatelessWidget {
  const _AuthHeader({
    required this.title,
    required this.subtitle,
    this.onBack,
    this.alignment = CrossAxisAlignment.center,
    this.logoWidth,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onBack;
  final CrossAxisAlignment alignment;

  /// Ancho del símbolo. Si se omite no se muestra la marca.
  final double? logoWidth;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isCentered = alignment == CrossAxisAlignment.center;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, isCentered ? 58 : 12, 24, 0),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          if (onBack != null) ...[
            RoutbIconButton(
              icon: Icons.arrow_back_rounded,
              onPressed: onBack,
              size: 48,
              semanticLabel: 'Volver',
              foreground: palette.ink,
            ),
            const SizedBox(height: 18),
          ],
          if (logoWidth != null) ...[
            Align(
              alignment: Alignment.center,
              child: RoutbLogo(
                variant: RoutbLogoVariant.onSurface.forBackground(
                  context.isDarkMode,
                ),
                width: logoWidth,
              ),
            ),
            const SizedBox(height: 16),
          ],
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
  });

  final TextEditingController phone;
  final TextEditingController password;
  final bool busy;
  final bool canSubmit;
  final VoidCallback onSubmit;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _AuthHeader(
          title: 'Iniciar sesión',
          subtitle: 'Continúa tu viaje con ROUTB',
          logoWidth: 112,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 26, 14, 0),
          child: AutofillGroup(
            child: RoutbCard(
              child: Column(
                children: [
                  RoutbField(
                    hint: 'Número de teléfono',
                    label: 'Teléfono',
                    autofillHints: const [
                      AutofillHints.telephoneNumberNational,
                    ],
                    icon: Icons.phone_rounded,
                    prefixText: '+57',
                    controller: phone,
                    errorText: phone.text.trim().isEmpty
                        ? null
                        : validatePhone(phone.text),
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
                    label: 'Contraseña',
                    autofillHints: const [AutofillHints.password],
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
        ),
      ],
    );
  }
}

class _RegisterStep extends StatelessWidget {
  const _RegisterStep({
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
  });

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

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _AuthHeader(
          title: 'Crear cuenta',
          subtitle: 'Únete a la comunidad universitaria de ROUTB',
          alignment: CrossAxisAlignment.start,
          logoWidth: 80,
          onBack: onBack,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 22, 14, 0),
          child: AutofillGroup(
            child: RoutbCard(
              child: Column(
                children: [
                  RoutbField(
                    hint: 'Nombre',
                    label: 'Nombre',
                    autofillHints: const [AutofillHints.givenName],
                    icon: Icons.person_outline_rounded,
                    controller: name,
                    errorText: name.text.trim().isEmpty
                        ? null
                        : validateName(name.text, 'nombre'),
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  RoutbField(
                    hint: 'Apellido',
                    label: 'Apellido',
                    autofillHints: const [AutofillHints.familyName],
                    icon: Icons.person_outline_rounded,
                    controller: lastName,
                    errorText: lastName.text.trim().isEmpty
                        ? null
                        : validateName(lastName.text, 'apellido'),
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  RoutbField(
                    hint: 'Teléfono',
                    label: 'Teléfono',
                    autofillHints: const [
                      AutofillHints.telephoneNumberNational,
                    ],
                    icon: Icons.phone_rounded,
                    prefixText: '+57',
                    controller: phone,
                    errorText: phone.text.trim().isEmpty
                        ? null
                        : validatePhone(phone.text),
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
                    label: 'Contraseña',
                    autofillHints: const [AutofillHints.newPassword],
                    icon: Icons.lock_rounded,
                    controller: password,
                    errorText: password.text.isEmpty
                        ? null
                        : validateNewPassword(password.text),
                    obscureToggle: true,
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 18),
                  RoutbCheckbox(
                    value: termsAccepted,
                    onChanged: busy ? null : onTermsChanged,
                    label: 'Acepto los Términos y Condiciones y autorizo el tratamiento de mis datos personales conforme a las políticas de ROUTB.',
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
        ),
      ],
    );
  }
}
