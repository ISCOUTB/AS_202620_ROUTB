import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../core/models/user_role.dart';
import '../../../core/services/device_launcher.dart';
import '../../../core/theme/routb_palette.dart';
import '../../../core/theme/routb_text.dart';
import '../../../core/theme/routb_theme.dart';
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
/// Arriba va el botón rojo para llamar al 123, separado del resto. Debajo, tres
/// entradas: Soporte, Contactos de emergencia e Información de seguridad. La
/// pantalla no depende de que haya un viaje activo.
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

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      children: [
        const RoutbSectionHeader(
          title: 'Seguridad',
          subtitle: 'Herramientas para actuar rápido',
        ),
        Expanded(
          child: ListView(
            key: const PageStorageKey<String>('security-tab'),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            children: [
              _EmergencyCallCard(onTap: _confirmEmergencyCall),
              const SizedBox(height: 14),
              RoutbCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _SafetyEntry(
                      icon: Icons.support_agent_rounded,
                      title: 'Soporte',
                      subtitle: 'Pide ayuda al equipo de ROUTB',
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
                    _entryDivider(palette),
                    _SafetyEntry(
                      icon: Icons.contacts_rounded,
                      title: 'Contactos de emergencia',
                      subtitle: _contactCount == 0
                          ? 'Guarda hasta 3 contactos en este dispositivo'
                          : '$_contactCount de ${EmergencyContactsStore.maxContacts} guardados',
                      onTap: _openContacts,
                    ),
                    _entryDivider(palette),
                    _SafetyEntry(
                      icon: Icons.shield_outlined,
                      title: 'Información de seguridad',
                      subtitle: widget.role == UserRole.driver
                          ? 'Consejos para conducir y recibir pasajeros'
                          : 'Consejos para viajar con tranquilidad',
                      onTap: () => Navigator.of(context).push(
                        RoutbPageRoute<void>(
                          child: SafetyInfoScreen(role: widget.role),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'La app no envía mensajes sola: abre WhatsApp o SMS con el '
                'texto listo para que tú lo envíes.',
                textAlign: TextAlign.center,
                style: RoutbText.copy(11.5, color: palette.muted, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _entryDivider(RoutbPalette palette) => Divider(
    height: 1,
    thickness: 1,
    indent: 64,
    color: palette.line.withValues(alpha: 0.75),
  );
}

/// Botón rojo, separado de las entradas, para llamar a la línea 123.
class _EmergencyCallCard extends StatelessWidget {
  const _EmergencyCallCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final foreground = palette.onBrand;

    return Semantics(
      button: true,
      label: 'Llamar al 123, línea de emergencias de Colombia',
      child: Material(
        color: palette.rose,
        borderRadius: BorderRadius.circular(RoutbTheme.radiusCard),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(RoutbTheme.radiusCard),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: foreground.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: foreground.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Icon(
                    Icons.emergency_rounded,
                    color: foreground,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Llamar al 123',
                        style: RoutbText.headline(18, color: foreground),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Línea de emergencias de Colombia',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RoutbText.copy(
                          12,
                          color: foreground.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.phone_in_talk_rounded, color: foreground, size: 20),
              ],
            ),
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
          padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: palette.brandSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: palette.brand, size: 20),
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
                        14,
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
              Icon(Icons.chevron_right_rounded, color: palette.muted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
