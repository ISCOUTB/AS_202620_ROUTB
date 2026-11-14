import 'package:flutter/material.dart';

import '../../../core/models/user_role.dart';
import '../../../core/theme/routb_palette.dart';
import '../../../core/theme/routb_text.dart';
import '../../../core/theme/routb_theme.dart';
import '../../../core/widgets/routb_card.dart';

/// Consejos de seguridad fijos, con una versión para pasajero y otra para
/// conductor.
///
/// El contenido es corto y se lee con scroll; no usa imágenes pesadas para que
/// funcione bien con datos móviles.
class SafetyInfoScreen extends StatelessWidget {
  const SafetyInfoScreen({required this.role, super.key});

  /// Rol que determina el texto.
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final passenger = role == UserRole.passenger;
    final sections = passenger ? _passengerSections : _driverSections;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(title: const Text('Información de seguridad')),
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
                  passenger
                      ? 'Viaja con tranquilidad'
                      : 'Conduce y recibe pasajeros con tranquilidad',
                  style: RoutbText.headline(22, color: palette.ink),
                ),
                const SizedBox(height: 6),
                Text(
                  passenger
                      ? 'Revisa estos consejos antes de solicitar un cupo y '
                            'durante el trayecto.'
                      : 'Revisa estos consejos antes de publicar una ruta y '
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

const List<_SafetySection> _passengerSections = <_SafetySection>[
  _SafetySection(
    icon: Icons.directions_car_rounded,
    title: 'Antes de subir',
    bullets: <String>[
      'Confirma la placa, el modelo, el color y el nombre del conductor antes de abrir la puerta.',
      'Pregunta “¿a quién viene a recoger?” y espera a que el conductor diga tu nombre.',
      'Espera en un punto iluminado y transitado; si puedes, hazlo desde un lugar cerrado hasta que el vehículo llegue.',
      'Si el vehículo o la persona no coinciden con la app, no subas y cancela la solicitud.',
      'No aceptes cambios de destino ni acuerdos por fuera de la app.',
    ],
  ),
  _SafetySection(
    icon: Icons.share_location_rounded,
    title: 'Comparte tu viaje',
    bullets: <String>[
      'Cuéntale a alguien de confianza tu ruta, la hora de salida, la placa y el nombre del conductor.',
      'Desde Contactos de emergencia puedes avisar por WhatsApp o SMS con el mensaje ya escrito.',
      'ROUTB no tiene seguimiento en vivo. Si compartes tu ubicación, hazlo por WhatsApp o SMS y solo con alguien de confianza.',
      'Si cambias de ruta o de conductor, vuelve a avisar.',
    ],
  ),
  _SafetySection(
    icon: Icons.event_seat_rounded,
    title: 'Durante el viaje',
    bullets: <String>[
      'Siéntate en la parte trasera y usa el cinturón de seguridad.',
      'Confía en tu instinto: si algo no se siente bien, pide bajar en un lugar seguro y avisa a alguien.',
      'No des vueltas ni camines hacia calles oscuras si no encuentras el vehículo; llama o escribe desde la app.',
      'No distraigas al conductor ni le pidas datos personales que no necesites.',
    ],
  ),
  _SafetySection(
    icon: Icons.lock_outline_rounded,
    title: 'Tus datos y tu ubicación',
    bullets: <String>[
      'El conductor ve tu nombre, tu teléfono y tu punto de encuentro cuando acepta tu solicitud.',
      'Tú ves el nombre y el teléfono del conductor; el modelo, el color y la placa aparecen cuando el cupo queda confirmado.',
      'La ubicación se usa para buscar direcciones y mostrar el trayecto; puedes cambiar los permisos desde los ajustes del teléfono.',
      'No compartas datos personales ni códigos de acceso fuera de la app.',
    ],
  ),
  _SafetySection(
    icon: Icons.support_agent_rounded,
    title: 'Si algo sale mal',
    bullets: <String>[
      'Usa el botón Llamar al 123 de la pestaña Seguridad.',
      'Cancela antes de subir si algo no coincide con la información de la app.',
      'Cuéntale a un contacto de confianza lo que pasó y guarda los datos del viaje.',
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
