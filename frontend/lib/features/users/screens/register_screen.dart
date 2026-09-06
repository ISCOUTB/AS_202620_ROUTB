import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/user_role.dart';
import '../../auth/services/auth_api.dart';
import '../../home/screens/dashboard_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.role});
  final UserRole role;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _acceptedTerms = false;
  final _authApi = AuthApi();

  @override
  void dispose() {
    _name.dispose();
    _lastName.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate() || !_acceptedTerms) return;
    try {
      await _authApi.register(
        phone: _phone.text.trim(),
        name: _name.text.trim(),
        lastName: _lastName.text.trim(),
        password: _password.text,
        role: widget.role,
      );
      final account = await _authApi.login(
        phone: _phone.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardScreen(
            role: account.role,
            userName: account.name,
          ),
        ),
      );
      return;
    } on AuthApiException catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(exception.message)),
        );
      }
      return;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo conectar con el servidor')),
        );
      }
      return;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF4F7FF),
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      leading: const BackButton(),
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Crear cuenta',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A2035),
                ),
              ),
              const SizedBox(height: 8),
              const Text('Únete a la comunidad universitaria de ROUTB'),
              const SizedBox(height: 28),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: _decoration('Nombre', Icons.person),
                validator: _required,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _lastName,
                textCapitalization: TextCapitalization.words,
                decoration: _decoration('Apellido', Icons.person_outline),
                validator: _required,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                decoration: _decoration(
                  'Teléfono',
                  Icons.phone,
                  prefixText: '+57 ',
                  suffix: _phone.text.length >= 10
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                ),
                validator: (value) => value == null || value.length < 10
                    ? 'Ingresa un teléfono válido'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                onChanged: (_) => setState(() {}),
                decoration: _decoration(
                  'Contraseña',
                  Icons.lock,
                  suffix: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_password.text.length >= 6)
                        const Icon(Icons.check_circle, color: Colors.green),
                      IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility,
                        ),
                      ),
                    ],
                  ),
                ),
                validator: (value) => value == null || value.length < 6
                    ? 'Mínimo 6 caracteres'
                    : null,
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _acceptedTerms,
                onChanged: (value) =>
                    setState(() => _acceptedTerms = value ?? false),
                title: const Text(
                  'Acepto los términos y el uso de mis datos en la UTB',
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _acceptedTerms ? _register : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5271FF),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Crear cuenta'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  String? _required(String? value) => value == null || value.trim().isEmpty
      ? 'Este campo es obligatorio'
      : null;

  InputDecoration _decoration(
    String label,
    IconData icon, {
    String? prefixText,
    Widget? suffix,
  }) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: const Color(0xFF5271FF)),
    prefixText: prefixText,
    suffixIcon: suffix,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  );
}
