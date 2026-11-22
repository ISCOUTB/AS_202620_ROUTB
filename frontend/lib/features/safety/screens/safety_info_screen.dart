import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../core/models/user_role.dart';
import '../../../core/theme/routb_palette.dart';
import '../../../core/theme/routb_text.dart';
import '../../../core/theme/routb_theme.dart';
import '../../../core/widgets/routb_button.dart';
import '../../../core/widgets/routb_card.dart';
import 'safety_detail_page.dart';

/// Consejos de seguridad fijos, con una versión para pasajero y otra para
/// conductor.
///
/// El contenido es corto y se lee con scroll; no usa imágenes pesadas para que
/// funcione bien con datos móviles.
class SafetyInfoScreen extends StatelessWidget {
  const SafetyInfoScreen({
    required this.role,
    this.guide,
    this.onCall,
    this.onContacts,
    this.onSupport,
    super.key,
  });

  /// Rol que determina el texto.
  final UserRole role;
  final PassengerSafetyGuide? guide;
  final VoidCallback? onCall;
  final VoidCallback? onContacts;
  final VoidCallback? onSupport;

  @override
  Widget build(BuildContext context) {
    if (guide case final guide?) {
      return SafetyDetailPage(
        title: guide.title,
        children: [
          for (final section in guide._sections) ...[
            _SafetySectionCard(section: section),
            const SizedBox(height: 12),
          ],
          if (guide == PassengerSafetyGuide.after && onSupport != null)
            RoutbButton(label: 'Abrir Soporte', onPressed: onSupport),
          if (guide == PassengerSafetyGuide.emergency) ...[
            if (onCall != null) EmergencyCallButton(onPressed: onCall!),
            const SizedBox(height: 12),
            if (onContacts != null)
              SafetyLink(
                title: 'Contactos de emergencia',
                subtitle: 'Avisa a alguien de confianza.',
                icon: Icons.people_outline_rounded,
                onTap: onContacts!,
              ),
          ],
        ],
      );
    }

    if (role == UserRole.passenger) {
      return SafetyDetailPage(
        title: 'Consejos para pasajeros',
        children: [
          for (final guide in PassengerSafetyGuide.values) ...[
            SafetyLink(
              icon: guide.icon,
              title: guide.title,
              subtitle: guide.subtitle,
              onTap: () => Navigator.of(context).push(
                RoutbPageRoute<void>(
                  child: SafetyInfoScreen(
                    role: role,
                    guide: guide,
                    onCall: onCall,
                    onContacts: onContacts,
                    onSupport: onSupport,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      );
    }

    final palette = context.palette;
    const sections = _driverSections;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(title: const Text('Consejos para conductores')),
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
                  'Conduce y recibe pasajeros con tranquilidad',
                  style: RoutbText.headline(22, color: palette.ink),
                ),
                const SizedBox(height: 6),
                Text(
                  'Revisa estos consejos antes de publicar una ruta y '
                  'mientras llevas pasajeros.',
                  style: RoutbText.copy(13, color: palette.muted, height: 1.4),
                ),
                const SizedBox(height: 16),
                for (var index = 0; index < sections.length; index++) ...[
                  _SafetySectionCard(section: sections[index]),
                  if (index != sections.length - 1) const SizedBox(height: 12),
                ],
                const SizedBox(height: 16),
                RoutbCard(
                  borderColor: palette.rose.withValues(alpha: 0.45),
                  borderWidth: 1,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.emergency_rounded,
                        color: palette.rose,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Ante una emergencia, llama al 123. ROUTB no '
                          'reemplaza a la línea de emergencias ni a las '
                          'autoridades.',
                          style: RoutbText.copy(
                            12,
                            color: palette.muted,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
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

class _SafetySection {
  const _SafetySection({
    required this.icon,
    required this.title,
    required this.bullets,
  });

  final IconData icon;
  final String title;
  final List<String> bullets;
}

class _SafetySectionCard extends StatelessWidget {
  const _SafetySectionCard({required this.section});

  final _SafetySection section;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return RoutbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: palette.brandSurface,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(section.icon, color: palette.brand, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  section.title,
                  style: RoutbText.copy(
                    15,
                    color: palette.ink,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final bullet in section.bullets)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: palette.brand,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      bullet,
                      style: RoutbText.copy(
                        13,
                        color: palette.muted,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

enum PassengerSafetyGuide {
  before(
    'Antes del viaje',
    'Revisa el cupo y prepara el encuentro.',
    Icons.fact_check_outlined,
    _beforeTrip,
  ),
  after(
    'Después del viaje',
    'Confirma tu llegada y revisa tus pertenencias.',
    Icons.directions_car_outlined,
    _afterTrip,
  ),
  emergency(
    'En caso de emergencia',
    'Busca ayuda y avisa a alguien de confianza.',
    Icons.emergency_outlined,
    _emergency,
  );

  const PassengerSafetyGuide(
    this.title,
    this.subtitle,
    this.icon,
    this._sections,
  );
  final String title;
  final String subtitle;
  final IconData icon;
  final List<_SafetySection> _sections;
}

const _beforeTrip = [
  _SafetySection(
    icon: Icons.route_rounded,
    title: 'Confirma la ruta y el encuentro',
    bullets: [
      'Revisa que el cupo esté confirmado y verifica el destino, el horario y el punto de encuentro en Mi viaje.',
      'Espera en un lugar iluminado y transitado, como una entrada del campus. Si hay un cambio, confirma el punto con el conductor por el contacto que figura en la app.',
    ],
  ),
  _SafetySection(
    icon: Icons.directions_car_rounded,
    title: 'Antes de subir',
    bullets: [
      'Compara el nombre del conductor, la placa, el modelo y el color con los datos del cupo confirmado.',
      'Si los datos no coinciden, quédate en un lugar seguro y cancela la solicitud si la opción está disponible.',
      'Avísale a alguien de confianza tu ruta y la hora estimada de llegada. Usa el cinturón durante el trayecto.',
    ],
  ),
];

const _afterTrip = [
  _SafetySection(
    icon: Icons.check_circle_outline_rounded,
    title: 'Confirma tu llegada',
    bullets: [
      'Comprueba que bajaste en el punto acordado y avisa que llegaste a la persona con quien compartiste el viaje.',
      'Antes de cerrar la puerta, revisa el asiento y dónde dejaste tu celular, carné, bolso o mochila.',
    ],
  ),
  _SafetySection(
    icon: Icons.support_agent_rounded,
    title: 'Si hubo un inconveniente',
    bullets: [
      'Si olvidaste algo, usa el contacto del conductor si sigue disponible y acuerda la entrega en un lugar público.',
      'Consulta Historial y registra el problema en Soporte. Incluye la fecha, la ruta y lo ocurrido para que el equipo pueda identificar el viaje.',
    ],
  ),
];

const _emergency = [
  _SafetySection(
    icon: Icons.health_and_safety_outlined,
    title: 'Ponte a salvo primero',
    bullets: [
      'Si te sientes en riesgo, pide bajar en un lugar público y transitado cuando sea seguro. Evita confrontar a quien te amenaza.',
      'Si hay un choque, aléjate del tráfico si puedes hacerlo con seguridad. Si alguien está herido, pide ayuda y sigue las instrucciones del operador.',
    ],
  ),
  _SafetySection(
    icon: Icons.phone_in_talk_rounded,
    title: 'Pide ayuda urgente',
    bullets: [
      'Si hay peligro inmediato o personas heridas, llama al 123. Indica dónde estás, qué pasó y cuántas personas necesitan ayuda.',
      'Cuando estés a salvo, avisa a un contacto de confianza y comparte tu ubicación o un punto de referencia.',
    ],
  ),
];

const List<_SafetySection> _driverSections = <_SafetySection>[
  _SafetySection(
    icon: Icons.fact_check_outlined,
    title: 'Antes de publicar',
    bullets: <String>[
      'Revisa que el modelo, el color y la placa estén correctos: es lo que el pasajero usa para identificarte.',
      'Elige un punto de encuentro seguro, iluminado, legal y con espacio para detenerte sin bloquear el tráfico.',
      'Publica solo rutas que realmente vas a hacer y con los cupos disponibles.',
      'Descansa antes de conducir y revisa que el vehículo esté limpio, ventilado y con combustible.',
    ],
  ),
  _SafetySection(
    icon: Icons.person_search_rounded,
    title: 'Al recibir pasajeros',
    bullets: <String>[
      'Confirma el nombre del pasajero y el número de cupos antes de iniciar.',
      'Detente del mismo lado de la acera que el pasajero y no lo obligues a cruzar.',
      'Si el pasajero no llega en unos minutos, cancela; no des vueltas esperando.',
      'No compartas tu teléfono personal ni tus datos fuera de la app.',
    ],
  ),
  _SafetySection(
    icon: Icons.route_rounded,
    title: 'Durante el viaje',
    bullets: <String>[
      'Usa el cinturón y pide a los pasajeros que también lo usen.',
      'Mantén la ruta y el mapa a la vista; evita distracciones y no uses el celular al conducir.',
      'No lleves acompañantes extraños ni cambies la ruta sin avisar a los pasajeros.',
      'Si algo se siente mal, detente en un lugar seguro y llama al 123.',
    ],
  ),
  _SafetySection(
    icon: Icons.visibility_outlined,
    title: 'Tus datos y los de tus pasajeros',
    bullets: <String>[
      'Los pasajeros ven tu nombre y la ruta publicada; el vehículo aparece cuando aceptas una solicitud.',
      'Tu teléfono está visible para el pasajero que solicita cupo.',
      'No publiques en redes sociales la ubicación ni los datos de tus pasajeros.',
      'La ubicación se usa para mostrar el trayecto; puedes revisar los permisos en los ajustes del teléfono.',
    ],
  ),
  _SafetySection(
    icon: Icons.health_and_safety_outlined,
    title: 'Si hay una emergencia',
    bullets: <String>[
      'Usa el botón Llamar al 123 de la pestaña Seguridad.',
      'No enfrentes una situación violenta: busca un lugar seguro y pide ayuda.',
      'Informa a un contacto de confianza y registra lo que puedas del incidente.',
    ],
  ),
];

class EmergencyCallButton extends StatelessWidget {
  const EmergencyCallButton({required this.onPressed, super.key});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 60),
        backgroundColor: Color.alphaBlend(
          p.rose.withValues(alpha: 0.16),
          p.roseSurface,
        ),
        foregroundColor: p.onRoseSurface,
        side: BorderSide(color: p.rose.withValues(alpha: 0.45)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      icon: const Icon(Icons.phone_in_talk_rounded, size: 24),
      label: Text(
        'Llamar al 123',
        style: RoutbText.headline(18, color: p.onRoseSurface),
      ),
    );
  }
}
