import '../utils/logger.dart';

class NotificationService {
  NotificationService._();

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    AppLogger.info('Notification service skipped (disabled)');
    _initialized = true;
  }

  static Future<void> showNotification({
    required String title,
    required String body,
    String? channelKey,
    Map<String, String>? payload,
  }) async {
    AppLogger.info('Skipped showing notification: $title - $body');
  }

  static Future<void> showLiveClassNotification({
    required String title,
    required String body,
    Map<String, String>? payload,
  }) async {
    AppLogger.info('Skipped live class notification: $title - $body');
  }
}
