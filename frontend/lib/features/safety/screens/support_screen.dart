import 'package:flutter/material.dart';

import '../../../core/widgets/route_actions.dart';

import '../../../app/app_routes.dart';
import '../../../app/dependencies.dart';
import '../../../core/theme/routb_palette.dart';
import '../../../core/widgets/routb_card.dart';
import 'safety_detail_page.dart';
import 'support_report_screen.dart';

enum SupportOption {
  report(
    'Reportar un problema',
    'Informa un problema de viaje, reserva, conductor o aplicación.',
    Icons.edit_note_rounded,
  ),
  faq(
    'Preguntas frecuentes',
    'Resuelve dudas sobre cupos, viajes y seguridad.',
    Icons.quiz_outlined,
  );

  const SupportOption(this.title, this.subtitle, this.icon);
  final String title;
  final String subtitle;
  final IconData icon;
}

class SupportScreen extends StatelessWidget {
  const SupportScreen({this.option, super.key});

  final SupportOption? option;

  @override
  Widget build(BuildContext context) {
    return switch (option) {
      SupportOption.report => SupportReportScreen(
        submit: RoutbScopeDependencies.of(context).support.submit,
      ),
      SupportOption.faq => const _SupportFaqScreen(),
      null => SafetyDetailPage(
        title: 'Soporte',
        children: [
          for (final option in SupportOption.values) ...[
            SafetyLink(
              icon: option.icon,
              title: option.title,
              subtitle: option.subtitle,
              onTap: () => context.pushFromCurrent(
                RoutbPageRoute<void>(child: SupportScreen(option: option)),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    };
  }
}

class _SupportFaqScreen extends StatelessWidget {
  const _SupportFaqScreen();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SafetyDetailPage(
      title: 'Preguntas frecuentes',
      children: [
        for (final (question, answer) in const [
          (
            '¿Cuándo queda confirmado mi cupo?',
            'La solicitud queda pendiente hasta que el conductor la acepte. Consulta su estado en Mi viaje.',
          ),
          (
            '¿Dónde veo los datos del vehículo?',
            'Abre Mi viaje cuando el cupo esté confirmado. Allí puedes consultar el modelo, el color y la placa.',
          ),
          (
            '¿Qué hago si ya no puedo viajar?',
            'Abre Mi viaje y cancela la solicitud cuanto antes si la opción está disponible.',
          ),
          (
            '¿Dónde veo mis viajes anteriores?',
            'Abre Historial para consultar los viajes completados y cancelados.',
          ),
          (
            '¿ROUTB comparte mi ubicación en vivo?',
            'ROUTB no ofrece seguimiento en vivo. Desde Seguridad puedes avisar a tus contactos de emergencia por WhatsApp o SMS.',
          ),
        ]) ...[
          RoutbCard(
            padding: EdgeInsets.zero,
            child: Material(
              type: MaterialType.transparency,
              child: ExpansionTile(
                title: Text(
                  question,
                  style: TextStyle(
                    color: palette.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedAlignment: AlignmentDirectional.centerStart,
                children: [
                  Text(answer, style: TextStyle(color: palette.muted)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
