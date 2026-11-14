import 'package:flutter/material.dart';

import '../../../core/models/user_role.dart';
import '../../../core/services/device_launcher.dart';
import '../../../core/theme/routb_palette.dart';
import '../../../core/theme/routb_text.dart';
import '../../../core/theme/routb_theme.dart';
import '../../../core/widgets/routb_card.dart';
import '../../../core/widgets/routb_toast.dart';
import '../models/active_trip_info.dart';
import '../support_config.dart';

/// Canal de soporte del equipo de ROUTB.
///
/// Muestra los canales disponibles como botones separados y abre la app
/// externa con el mensaje ya escrito. No se envía nada desde ROUTB.
class SupportScreen extends StatelessWidget {
  const SupportScreen({
    required this.userName,
    required this.role,
    this.launcher = const DeviceLauncher(),
    super.key,
  });

  /// Nombre que se incluye en el mensaje.
  final String userName;

  /// Rol que se incluye en el mensaje.
  final UserRole role;

  /// Acciones externas.
  final DeviceLauncher launcher;

  String get _roleLabel => role == UserRole.driver ? 'conductor' : 'pasajero';

  String get _message =>
      supportMessage(userName: userName, roleLabel: _roleLabel);

  Future<void> _openWhatsApp(BuildContext context) async {
    if (!SupportConfig.hasWhatsApp) {
      RoutbToast.show(
        context,
        'El canal de WhatsApp de soporte todavía no está configurado.',
      );
      return;
    }
    final opened = await launcher.whatsapp(
      SupportConfig.whatsappNumber,
      message: _message,
    );
    if (!opened && context.mounted) {
      RoutbToast.show(
        context,
        'No se pudo abrir WhatsApp. Revisa que esté instalado en el teléfono.',
      );
    }
  }

  Future<void> _openEmail(BuildContext context) async {
    if (!SupportConfig.hasEmail) {
      RoutbToast.show(
        context,
        'El correo de soporte todavía no está configurado.',
      );
      return;
    }
    final opened = await launcher.email(
      SupportConfig.email,
      subject: 'Ayuda con ROUTB',
      body: _message,
    );
    if (!opened && context.mounted) {
      RoutbToast.show(
        context,
        'No se pudo abrir la app de correo. Revisa que esté configurada.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(title: const Text('Soporte')),
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
                Text(
                  '¿Necesitas ayuda?',
                  style: RoutbText.headline(22, color: palette.ink),
                ),
                const SizedBox(height: 6),
                Text(
                  'Elige un canal y te atendemos lo antes posible. El mensaje '
                  'ya incluye tu nombre y tu rol.',
                  style: RoutbText.copy(13, color: palette.muted, height: 1.4),
                ),
                const SizedBox(height: 16),
                _SupportChannelCard(
                  icon: Icons.chat_bubble_rounded,
                  title: 'Escribir por WhatsApp',
                  subtitle: SupportConfig.hasWhatsApp
                      ? 'Abre WhatsApp con el mensaje listo'
                      : 'Canal por configurar',
                  accent: palette.mint,
                  surface: palette.mintSurface,
                  onTap: () => _openWhatsApp(context),
                ),
                const SizedBox(height: 12),
                _SupportChannelCard(
                  icon: Icons.mail_outline_rounded,
                  title: 'Enviar un correo',
                  subtitle: SupportConfig.hasEmail
                      ? SupportConfig.email
                      : 'Canal por configurar',
                  accent: palette.brand,
                  surface: palette.brandSurface,
                  onTap: () => _openEmail(context),
                ),
                const SizedBox(height: 16),
                Text(
                  'Si es una emergencia, no esperes respuesta por aquí: usa el '
                  'botón Llamar al 123 de la pestaña Seguridad.',
                  style: RoutbText.copy(12, color: palette.muted, height: 1.4),
                ),
                const SizedBox(height: 10),
                Text(
                  'Mensaje: “$_message”',
                  style: RoutbText.copy(
                    11.5,
                    color: palette.muted,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 4),
                if (!SupportConfig.hasWhatsApp && !SupportConfig.hasEmail)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: RoutbCard(
                      borderColor: palette.amber.withValues(alpha: 0.45),
                      borderWidth: 1,
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: palette.amber,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'El equipo todavía no definió el número ni el '
                              'correo de soporte. Los botones quedan listos '
                              'para cuando se configuren.',
                              style: RoutbText.copy(
                                12,
                                color: palette.muted,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SupportChannelCard extends StatelessWidget {
  const _SupportChannelCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.surface,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final Color surface;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: Material(
        color: palette.card,
        borderRadius: BorderRadius.circular(RoutbTheme.radiusCard),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(RoutbTheme.radiusCard),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(RoutbTheme.radiusCard),
              border: Border.all(color: palette.line.withValues(alpha: 0.7)),
              boxShadow: palette.cardShadow,
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RoutbText.copy(
                          14.5,
                          color: palette.ink,
                          weight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RoutbText.copy(12, color: palette.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.open_in_new_rounded, color: palette.muted, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
