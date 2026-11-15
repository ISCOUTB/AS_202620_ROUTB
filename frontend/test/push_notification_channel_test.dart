import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/notifications/push_notification_service.dart';

void main() {
  group('PushNotificationService · canal por evento (G21)', () {
    test('una solicitud nueva usa el canal de nuevas solicitudes', () {
      expect(
        PushNotificationService.channelIdForEvent('request_created'),
        PushNotificationService.channelNewRequests,
      );

      final details = PushNotificationService.detailsForEvent(
        'request_created',
      );
      final android = details.android!;
      expect(android.channelId, PushNotificationService.channelNewRequests);
      expect(android.importance, Importance.max);
      expect(android.vibrationPattern, isNotNull);
    });

    test('aceptación y rechazo usan el canal de actualizaciones', () {
      for (final event in <String>[
        'request_accepted',
        'request_rejected',
        'trip_cancelled',
      ]) {
        expect(
          PushNotificationService.channelIdForEvent(event),
          PushNotificationService.channelUpdates,
        );
        final android = PushNotificationService.detailsForEvent(event).android!;
        expect(android.channelId, PushNotificationService.channelUpdates);
        expect(android.vibrationPattern, isNull);
      }
    });
  });
}
