import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/routb_palette.dart';
import '../theme/routb_text.dart';
import '../theme/routb_theme.dart';
import '../widgets/routb_toast.dart';

/// Utilidad para iniciar conversaciones directas en WhatsApp (wa.me) con formato
/// de número colombiano e internacional normalizado.
class WhatsAppLauncher {
  const WhatsAppLauncher._();

  /// Limpia y normaliza el número de teléfono para WhatsApp (`wa.me`).
  ///
  /// Remueve caracteres no numéricos. Si es un móvil colombiano de 10 dígitos
  /// (que inicia en 3), le antepone el código de país '57'.
  static String normalizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10 && digits.startsWith('3')) {
      return '57$digits';
    }
    return digits;
  }

  /// Construye la URL de WhatsApp (`https://wa.me/...`).
  static Uri buildUri({required String phone, String? message}) {
    final cleanPhone = normalizePhone(phone);
    if (message != null && message.trim().isNotEmpty) {
      return Uri.parse(
        'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message.trim())}',
      );
    }
    return Uri.parse('https://wa.me/$cleanPhone');
  }

  /// Intenta abrir WhatsApp en una aplicación externa.
  static Future<bool> launch({required String phone, String? message}) async {
    final uri = buildUri(phone: phone, message: message);
    if (normalizePhone(phone).isEmpty) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Abre WhatsApp y muestra un mensaje de retroalimentación si falla.
  static Future<void> open({
    required BuildContext context,
    required String phone,
    String? message,
  }) async {
    final success = await launch(phone: phone, message: message);
    if (!success && context.mounted) {
      RoutbToast.show(context, 'No se pudo abrir WhatsApp para este contacto');
    }
  }
}

/// Botón estilizado para contactar por WhatsApp respetando la paleta de ROUTB.
class WhatsAppButton extends StatelessWidget {
  const WhatsAppButton({
    required this.phone,
    this.message,
    this.label = 'WhatsApp',
    this.compact = false,
    super.key,
  });

  final String phone;
  final String? message;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Material(
      color: palette.mintSurface,
      borderRadius: BorderRadius.circular(RoutbTheme.radiusPill),
      child: InkWell(
        onTap: () => WhatsAppLauncher.open(
          context: context,
          phone: phone,
          message: message,
        ),
        borderRadius: BorderRadius.circular(RoutbTheme.radiusPill),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 9 : 12,
            vertical: compact ? 5 : 7,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble_rounded,
                size: compact ? 13 : 15,
                color: palette.onMintSurface,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: RoutbText.copy(
                  compact ? 11 : 12,
                  color: palette.onMintSurface,
                  weight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
