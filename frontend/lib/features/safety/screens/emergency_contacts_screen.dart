import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/device_launcher.dart';
import '../../../core/theme/routb_palette.dart';
import '../../../core/theme/routb_text.dart';
import '../../../core/theme/routb_theme.dart';
import '../../../core/widgets/routb_button.dart';
import '../../../core/widgets/routb_card.dart';
import '../../../core/widgets/routb_field.dart';
import '../../../core/widgets/routb_seats.dart';
import '../../../core/widgets/routb_sheet.dart';
import '../../../core/widgets/routb_toast.dart';
import '../data/emergency_contacts_store.dart';
import '../models/active_trip_info.dart';
import '../models/emergency_contact.dart';

/// Contactos de emergencia guardados solo en el dispositivo.
///
/// No se pide permiso de contactos: el nombre y el teléfono se escriben a mano.
/// Desde cada contacto se puede llamar o abrir WhatsApp o SMS con un mensaje ya
/// escrito; la app nunca envía nada por su cuenta.
class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({
    required this.userName,
    this.activeTrip,
    this.launcher = const DeviceLauncher(),
    this.store = const EmergencyContactsStore(),
    super.key,
  });

  /// Nombre que se incluye en el mensaje.
  final String userName;

  /// Viaje activo, si lo hay, para incluirlo en el mensaje.
  final ActiveTripInfo? activeTrip;

  /// Acciones externas.
  final DeviceLauncher launcher;

  /// Almacenamiento local.
  final EmergencyContactsStore store;

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  List<EmergencyContact> _contacts = const <EmergencyContact>[];
  bool _loading = true;

  String get _message => emergencyContactMessage(
    userName: widget.userName,
    activeTrip: widget.activeTrip,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final contacts = await widget.store.load();
    if (!mounted) return;
    setState(() {
      _contacts = contacts;
      _loading = false;
    });
  }

  Future<void> _save(List<EmergencyContact> contacts) async {
    await widget.store.save(contacts);
    if (!mounted) return;
    setState(() => _contacts = contacts);
  }

  Future<void> _openForm([EmergencyContact? contact]) async {
    if (contact == null &&
        _contacts.length >= EmergencyContactsStore.maxContacts) {
      RoutbToast.show(
        context,
        'Puedes guardar hasta ${EmergencyContactsStore.maxContacts} contactos.',
      );
      return;
    }
    final result = await RoutbSheet.show<EmergencyContact>(
      context: context,
      title: contact == null ? 'Agregar contacto' : 'Editar contacto',
      subtitle: 'Solo se guarda en este dispositivo.',
      heightFactor: 0.66,
      body: _ContactForm(contact: contact),
    );
    if (result == null || !mounted) return;

    final next = <EmergencyContact>[..._contacts];
    if (contact == null) {
      next.add(result);
    } else {
      final index = next.indexWhere((item) => item.id == contact.id);
      if (index >= 0) next[index] = result;
    }
    await _save(next);
    if (mounted) RoutbToast.show(context, 'Contacto guardado');
  }

  Future<void> _confirmDelete(EmergencyContact contact) async {
    final palette = context.palette;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar este contacto?'),
        content: Text(
          '${contact.name} dejará de aparecer en tus contactos de emergencia.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Mantener'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Eliminar', style: TextStyle(color: palette.rose)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _save(
      _contacts.where((item) => item.id != contact.id).toList(growable: false),
    );
    if (mounted) RoutbToast.show(context, 'Contacto eliminado');
  }

  Future<void> _showActions(EmergencyContact contact) async {
    final palette = context.palette;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.surface,
      constraints: const BoxConstraints(maxWidth: 640),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(RoutbTheme.radiusSheet),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Row(
                children: [
                  InitialsAvatar(
                    name: contact.name,
                    initials: contact.initials,
                    size: 40,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contact.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: RoutbText.copy(
                            15,
                            color: palette.ink,
                            weight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          contact.phone,
                          style: RoutbText.copy(12, color: palette.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _ActionTile(
              icon: Icons.call_rounded,
              label: 'Llamar',
              onTap: () {
                Navigator.of(sheetContext).pop();
                unawaited(_call(contact));
              },
            ),
            _ActionTile(
              icon: Icons.chat_bubble_rounded,
              label: 'Avisar por WhatsApp',
              onTap: () {
                Navigator.of(sheetContext).pop();
                unawaited(_whatsapp(contact));
              },
            ),
            _ActionTile(
              icon: Icons.sms_outlined,
              label: 'Avisar por SMS',
              onTap: () {
                Navigator.of(sheetContext).pop();
                unawaited(_sms(contact));
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _call(EmergencyContact contact) async {
    final opened = await widget.launcher.call(contact.phone);
    if (!opened && mounted) {
      RoutbToast.show(context, 'No se pudo abrir el marcador.');
    }
  }

  Future<void> _whatsapp(EmergencyContact contact) async {
    final opened = await widget.launcher.whatsapp(
      contact.phone,
      message: _message,
    );
    if (!opened && mounted) {
      await _offerSms(contact);
    }
  }

  Future<void> _offerSms(EmergencyContact contact) async {
    final palette = context.palette;
    final sendSms = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('WhatsApp no está disponible'),
        content: const Text(
          'No se pudo abrir WhatsApp. ¿Quieres avisar a este contacto por SMS?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Enviar SMS', style: TextStyle(color: palette.brand)),
          ),
        ],
      ),
    );
    if (sendSms == true && mounted) await _sms(contact);
  }

  Future<void> _sms(EmergencyContact contact) async {
    final opened = await widget.launcher.sms(contact.phone, message: _message);
    if (!opened && mounted) {
      RoutbToast.show(context, 'No se pudo abrir la app de SMS.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(title: const Text('Contactos de emergencia')),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: RoutbTheme.contentMaxWidth,
            ),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    key: const PageStorageKey<String>('emergency-contacts'),
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
                    children: [
                      Text(
                        'Avisa a alguien de confianza cuando salgas o llegues. '
                        'Puedes guardar hasta ${EmergencyContactsStore.maxContacts} '
                        'contactos.',
                        style: RoutbText.copy(
                          13,
                          color: palette.muted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_contacts.isEmpty)
                        RoutbCard(
                          child: Column(
                            children: [
                              Icon(
                                Icons.contacts_outlined,
                                color: palette.brand,
                                size: 34,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Todavía no tienes contactos de emergencia.',
                                textAlign: TextAlign.center,
                                style: RoutbText.copy(
                                  14,
                                  color: palette.ink,
                                  weight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Agrega el nombre y el teléfono de alguien de '
                                'confianza.',
                                textAlign: TextAlign.center,
                                style: RoutbText.copy(
                                  12,
                                  color: palette.muted,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        for (final contact in _contacts) ...[
                          _ContactCard(
                            contact: contact,
                            onTap: () => _showActions(contact),
                            onEdit: () => _openForm(contact),
                            onDelete: () => _confirmDelete(contact),
                          ),
                          const SizedBox(height: 10),
                        ],
                      const SizedBox(height: 4),
                      if (_contacts.length < EmergencyContactsStore.maxContacts)
                        RoutbButton(
                          label: 'Agregar contacto',
                          icon: Icons.person_add_alt_1_rounded,
                          onPressed: _openForm,
                        )
                      else
                        Text(
                          'Llegaste al límite de '
                          '${EmergencyContactsStore.maxContacts} contactos.',
                          textAlign: TextAlign.center,
                          style: RoutbText.copy(12, color: palette.muted),
                        ),
                      const SizedBox(height: 14),
                      Text(
                        'No pedimos permiso a tus contactos del teléfono: el '
                        'número se escribe a mano y solo se guarda en este '
                        'dispositivo.',
                        textAlign: TextAlign.center,
                        style: RoutbText.copy(
                          11.5,
                          color: palette.muted,
                          height: 1.35,
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

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.contact,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final EmergencyContact contact;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return RoutbCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      semanticLabel: '${contact.name}, ${contact.phone}',
      child: Row(
        children: [
          InitialsAvatar(
            name: contact.name,
            initials: contact.initials,
            size: 42,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  contact.name,
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
                  contact.phone,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RoutbText.copy(12, color: palette.muted),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Opciones de ${contact.name}',
            icon: Icon(Icons.more_vert_rounded, color: palette.muted, size: 20),
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'edit',
                child: Text('Editar contacto'),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Text('Eliminar contacto'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ListTile(
      leading: Icon(icon, color: palette.brand),
      title: Text(label),
      onTap: onTap,
    );
  }
}

class _ContactForm extends StatefulWidget {
  const _ContactForm({this.contact});

  final EmergencyContact? contact;

  @override
  State<_ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends State<_ContactForm> {
  late final TextEditingController _name = TextEditingController(
    text: widget.contact?.name ?? '',
  );
  late final TextEditingController _phone = TextEditingController(
    text: widget.contact?.phone ?? '',
  );
  String? _nameError;
  String? _phoneError;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _save() {
    final nameError = validateContactName(_name.text);
    final phoneError = validateContactPhone(_phone.text);
    if (nameError != null || phoneError != null) {
      setState(() {
        _nameError = nameError;
        _phoneError = phoneError;
      });
      return;
    }

    Navigator.of(context).pop(
      EmergencyContact(
        id:
            widget.contact?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        name: _name.text.trim(),
        phone: _phone.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RoutbField(
          hint: 'Nombre del contacto',
          icon: Icons.person_outline_rounded,
          controller: _name,
          textCapitalization: TextCapitalization.words,
          errorText: _nameError,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        RoutbField(
          hint: 'Teléfono',
          icon: Icons.phone_outlined,
          controller: _phone,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-()]')),
          ],
          errorText: _phoneError,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: 16),
        Text(
          'Escribe el número con el indicador del país si es de otro lugar. '
          'No se pide permiso de contactos.',
          style: RoutbText.copy(11.5, color: palette.muted, height: 1.35),
        ),
        const SizedBox(height: 18),
        RoutbButton(
          label: widget.contact == null
              ? 'Guardar contacto'
              : 'Guardar cambios',
          icon: Icons.check_rounded,
          onPressed: _save,
        ),
      ],
    );
  }
}
