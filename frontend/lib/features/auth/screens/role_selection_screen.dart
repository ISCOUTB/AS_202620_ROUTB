import 'package:flutter/material.dart';

import '../../../core/models/user_role.dart';
import 'login_screen.dart';
import '../../users/screens/register_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  static const _background = Color(0xFFF4F7FF);
  static const _text = Color(0xFF1A2035);

  void _selectRole(BuildContext context, UserRole role) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RegisterScreen(role: role)),
    );
  }

  void _goBack(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Regresar',
          onPressed: () => _goBack(context),
          icon: const Icon(Icons.arrow_back_rounded, color: _text),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  width: 130,
                  height: 130,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 24),
                const Text(
                  '¿Cómo vas a viajar?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _text,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Elige tu perfil para continuar',
                  style: TextStyle(
                    color: _text.withValues(alpha: .65),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 32),
                _RoleCard(
                  icon: Icons.school_rounded,
                  title: 'Soy Pasajero',
                  description: 'Encuentra un viaje seguro hasta la UTB.',
                  onTap: () => _selectRole(context, UserRole.passenger),
                ),
                const SizedBox(height: 16),
                _RoleCard(
                  icon: Icons.directions_car_rounded,
                  title: 'Soy Conductor',
                  description: 'Comparte tu ruta y ayuda a otros estudiantes.',
                  onTap: () => _selectRole(context, UserRole.driver),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: const Color(0xFF5271FF).withValues(alpha: .12)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: const Color(0xFF5271FF).withValues(alpha: .12),
                child: Icon(icon, color: const Color(0xFF5271FF), size: 30),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A2035),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: Color(0xFF5271FF),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
