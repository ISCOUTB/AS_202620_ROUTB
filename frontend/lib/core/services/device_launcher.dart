import 'package:url_launcher/url_launcher.dart';

import 'whatsapp_launcher.dart';

/// Abre una URL fuera de la app. Se inyecta en las pruebas para no tocar el
/// marcador, WhatsApp ni el correo del dispositivo.
typedef UriLauncher = Future<bool> Function(Uri uri);

/// Acciones externas que usa la pestaña Seguridad.
///
/// La app no llama ni envía mensajes por su cuenta: solo abre la app del
/// sistema con el número o el texto ya preparado, y la persona confirma el
/// envío. Si el dispositivo no puede abrir la app, se devuelve `false` para que
/// la pantalla avise en vez de fallar en silencio.
class DeviceLauncher {
  const DeviceLauncher({this.launchUri = _launch});

  /// Función que abre la URL. Por defecto usa `url_launcher`.
  final UriLauncher launchUri;

  static Future<bool> _launch(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Abre el marcador con [phone]. Funciona sin internet.
  Future<bool> call(String phone) {
    final number = _numbersAndPlus(phone);
    if (number.isEmpty) return Future<bool>.value(false);
    return launchUri(Uri(scheme: 'tel', path: number));
  }

  /// Abre la app de SMS con [message] ya escrito.
  Future<bool> sms(String phone, {String? message}) {
    final number = _numbersAndPlus(phone);
    if (number.isEmpty) return Future<bool>.value(false);
    final text = message?.trim();
    return launchUri(
      Uri(
        scheme: 'sms',
        path: number,
        queryParameters: text == null || text.isEmpty
            ? null
            : <String, String>{'body': text},
      ),
    );
  }

  /// Abre WhatsApp con el número y el mensaje ya preparados.
  Future<bool> whatsapp(String phone, {String? message}) {
    if (phone.replaceAll(RegExp(r'\D'), '').isEmpty) {
      return Future<bool>.value(false);
    }
    return launchUri(WhatsAppLauncher.buildUri(phone: phone, message: message));
  }

  /// Abre la app de correo con asunto y cuerpo ya escritos.
  Future<bool> email(String address, {String? subject, String? body}) {
    final clean = address.trim();
    if (clean.isEmpty) return Future<bool>.value(false);
    final query = <String, String>{
      if (subject != null && subject.trim().isNotEmpty)
        'subject': subject.trim(),
      if (body != null && body.trim().isNotEmpty) 'body': body.trim(),
    };
    return launchUri(
      Uri(
        scheme: 'mailto',
        path: clean,
        queryParameters: query.isEmpty ? null : query,
      ),
    );
  }

  /// Conserva el `+` inicial y descarta espacios, guiones y paréntesis.
  static String _numbersAndPlus(String raw) {
    final trimmed = raw.trim();
    final digits = trimmed.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.startsWith('+')) {
      return '+${digits.substring(1).replaceAll('+', '')}';
    }
    return digits.replaceAll('+', '');
  }
}
