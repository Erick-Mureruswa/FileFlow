import 'dart:async';

import 'package:fileflow/app.dart';
import 'package:fileflow/core/background/workmanager_tasks.dart';
import 'package:fileflow/core/services/notification_service.dart';
import 'package:fileflow/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  // Run inside a guarded zone so any uncaught async error is logged instead of
  // silently crashing the app.
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Lock the app to portrait — its layouts are designed for it.
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);

      // Surface framework build/render errors in logs.
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        debugPrint('FlutterError: ${details.exceptionAsString()}');
      };

      // Best-effort init: a failure here must not block the app from launching.
      try {
        await NotificationService.instance.init();
        // Notification taps just navigate home; user switches tabs from there.
        NotificationService.instance.onNotificationTap = (_) {
          appRouter.go('/');
        };
        await WorkManagerTasks.init();
      } on Exception catch (e) {
        debugPrint('Startup init warning: $e');
      }

      runApp(const ProviderScope(child: FileFlowApp()));
    },
    (error, stack) => debugPrint('Uncaught zone error: $error'),
  );
}
