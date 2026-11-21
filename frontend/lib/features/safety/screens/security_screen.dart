import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../core/models/user_role.dart';
import '../../../core/services/device_launcher.dart';
import '../../../core/theme/routb_palette.dart';
import '../../../core/theme/routb_text.dart';
import '../../../core/widgets/routb_card.dart';
import '../../../core/widgets/routb_section_header.dart';
import '../../../core/widgets/routb_toast.dart';
import '../data/emergency_contacts_store.dart';
import '../models/active_trip_info.dart';
import 'emergency_contacts_screen.dart';
import 'safety_info_screen.dart';
import 'support_screen.dart';

/// Pestaña Seguridad, igual para pasajeros y conductores.
///
class SecurityScreen extends StatefulWidget {
  const SecurityScreen({
    required this.role,
    required this.userName,
    this.activeTrip,
    this.launcher = const DeviceLauncher(),
    this.contactsStore = const EmergencyContactsStore(),
    super.key,
  });

  /// Rol de quien está usando la app.
  final UserRole role;

  /// Nombre para los mensajes prellenados.
  final String userName;

  /// Viaje activo, si lo hay, para incluirlo en el aviso a un contacto.
  final ActiveTripInfo? activeTrip;

  /// Acciones externas (marcador, WhatsApp, SMS y correo).
  final DeviceLauncher launcher;

  /// Almacenamiento local de contactos.
  final EmergencyContactsStore contactsStore;

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  int _contactCount = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadContactCount());
  }

  Future<void> _loadContactCount() async {
    final contacts = await widget.contactsStore.load();
    if (mounted) setState(() => _contactCount = contacts.length);
  }

  Future<void> _confirmEmergencyCall() async {
    final palette = context.palette;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Llamar al 123?'),
        content: const Text(
          'Vas a salir de ROUTB para llamar a la línea de emergencias de '
          'Colombia. Confirma solo si necesitas ayuda urgente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Llamar', style: TextStyle(color: palette.rose)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final opened = await widget.launcher.call('123');
    if (!opened && mounted) {
      RoutbToast.show(
        context,
        'No se pudo abrir el marcador. Marca 123 desde tu teléfono.',
      );
    }
  }

  Future<void> _openContacts() async {
    await Navigator.of(context).push(
      RoutbPageRoute<void>(
        child: EmergencyContactsScreen(
          userName: widget.userName,
          activeTrip: widget.activeTrip,
          launcher: widget.launcher,
          store: widget.contactsStore,
        ),
      ),
    );
    if (mounted) await _loadContactCount();
  }

  Future<void> _openSafetyInfo() async {
    await Navigator.of(context)
        .push(RoutbPageRoute<void>(child: SafetyInfoScreen(role: widget.role)));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final driver = widget.role == UserRole.driver;
    final contacts = _ContactPass(count: _contactCount, onTap: _openContacts);
    final resources = RoutbCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _SafetyEntry(
            icon: driver
                ? Icons.directions_car_outlined
                : Icons.directions_walk_rounded,
            title: driver
                ? 'Consejos para conductores'
                : 'Consejos para pasajeros',
            subtitle: driver
                ? 'Recomendaciones para una ruta segura'
                : 'Viaja con tranquilidad y confianza',
            onTap: _openSafetyInfo,
          ),
          Divider(height: 1, indent: 66, color: p.line),
          _SafetyEntry(
            icon: Icons.headset_mic_outlined,
            title: 'Soporte',
            subtitle: 'Hablar con el equipo de ROUTB',
            onTap: () => Navigator.of(context).push(
              RoutbPageRoute<void>(
                child: SupportScreen(
                  userName: widget.userName,
                  role: widget.role,
                  launcher: widget.launcher,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    final call = FilledButton.icon(
      onPressed: _confirmEmergencyCall,
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        backgroundColor: p.roseSurface,
        foregroundColor: p.onRoseSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      icon: const Icon(Icons.phone_in_talk_rounded),
      label: Text(
        'Llamar al 123',
        style: RoutbText.headline(17, color: p.onRoseSurface),
      ),
    );

    return RoutbSectionPage(
      title: 'Seguridad',
      subtitle: 'Herramientas para tu viaje',
      icon: Icons.shield_outlined,
      primary: call,
      body: (split) => ListView(
        key: const PageStorageKey<String>('security-tab'),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
        children: [
          if (!split) ...[call, const SizedBox(height: 12)],
          contacts,
          const SizedBox(height: 12),
          resources,
        ],
      ),
    );
  }
}

class _ContactPass extends StatelessWidget {
  const _ContactPass({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.mintSurface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Contactos de emergencia',
                      style: RoutbText.headline(19, color: p.onMintSurface),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: p.onMintSurface,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ExcludeSemantics(
                    child: Row(
                      children: [
                        for (
                          var i = 0;
                          i < EmergencyContactsStore.maxContacts;
                          i++
                        )
                          Icon(
                            i < count
                                ? Icons.person_rounded
                                : Icons.person_outline_rounded,
                            color: p.onMintSurface,
                            size: 18,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$count de ${EmergencyContactsStore.maxContacts} guardados',
                      style: RoutbText.copy(12, color: p.onMintSurface),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Tú eliges cuándo enviar el aviso por WhatsApp o SMS.',
                style: RoutbText.copy(13, color: p.onMintSurface),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SafetyEntry extends StatelessWidget {
  const _SafetyEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: palette.brandSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: palette.onBrandSurface, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,

                      style: RoutbText.copy(
                        14,
                        color: palette.ink,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: MediaQuery.textScalerOf(context).scale(16) <= 16
                          ? 1
                          : null,
                      overflow: TextOverflow.ellipsis,

                      style: RoutbText.copy(12, color: palette.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, color: palette.muted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
