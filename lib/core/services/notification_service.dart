import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Notification IDs — stable across sessions so Android deduplicates.
const _kIdCleanupComplete = 1;
const _kIdExpiringSoon = 2;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'fileflow_main';
  static const _channelName = 'FileFlow';
  static const _channelDesc = 'File cleanup and expiry notifications';

  /// Register this from main.dart to handle notification taps for navigation.
  /// Called with the notification ID when the user taps a notification.
  void Function(int notificationId)? onNotificationTap;

  Future<void> init() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _handleTap,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDesc,
            importance: Importance.defaultImportance,
          ),
        );
  }

  void _handleTap(NotificationResponse response) {
    final id = response.id;
    if (id != null) onNotificationTap?.call(id);
  }

  Future<bool> requestPermission() async {
    final result = await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    return result ?? false;
  }

  Future<void> showCleanupComplete({
    required int deletedCount,
    required int bytesFreed,
  }) async {
    const bytesPerMb = 1024 * 1024;
    final mb = bytesFreed ~/ bytesPerMb;
    await _plugin.show(
      _kIdCleanupComplete,
      'FileFlow — Cleanup complete',
      'Deleted $deletedCount files · Freed ${mb}MB',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          icon: '@mipmap/ic_launcher',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
    );
  }

  Future<void> showFilesExpiringSoon(int count) async {
    await _plugin.show(
      _kIdExpiringSoon,
      'Files expiring soon',
      '$count ${count == 1 ? 'file' : 'files'} will be deleted within 24 hours. Tap to review.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          icon: '@mipmap/ic_launcher',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  Future<void> cancel(int id) => _plugin.cancel(id);
}
