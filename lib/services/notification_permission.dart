import 'package:flutter/services.dart';

/// Android 13+ gates notifications behind a runtime permission, separate from
/// the manifest declaration.
///
/// Native code posts the remaining-time alerts from the accessibility service,
/// so Dart only has to ask for the permission and point at the right settings
/// screen when it is denied. Runs that cannot answer the channel (tests, or a
/// platform without it) are treated as "allowed", which keeps the feature from
/// blocking on a question that cannot be asked.
class NotificationPermission {
  const NotificationPermission._();

  static const MethodChannel _channel = MethodChannel('app_closure');

  static Future<bool> isGranted() async {
    try {
      return await _channel.invokeMethod<bool>('hasNotificationPermission') ??
          true;
    } catch (_) {
      return true;
    }
  }

  static Future<bool> request() async {
    try {
      return await _channel
              .invokeMethod<bool>('requestNotificationPermission') ??
          true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> openSettings() async {
    try {
      await _channel.invokeMethod<void>('openNotificationSettings');
    } catch (_) {
      // The settings screen is a convenience, not part of enforcement.
    }
  }
}
