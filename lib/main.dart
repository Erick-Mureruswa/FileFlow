import 'package:fileflow/app.dart';
import 'package:fileflow/core/background/workmanager_tasks.dart';
import 'package:fileflow/core/services/notification_service.dart';
import 'package:fileflow/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationService.instance.init();

  // Notification ID 1 → cleanup complete → go to Files tab (home).
  // Notification ID 2 → files expiring soon → go to Swipe Cleanup.
  // Both just navigate to home; the user can switch tabs from there.
  NotificationService.instance.onNotificationTap = (id) {
    appRouter.go('/');
  };

  await WorkManagerTasks.init();

  runApp(const ProviderScope(child: FileFlowApp()));
}
