import 'package:fileflow/core/theme/app_theme.dart';
import 'package:fileflow/features/file_arrival/file_arrival_scope.dart';
import 'package:fileflow/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FileFlowApp extends ConsumerWidget {
  const FileFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'FileFlow',
      theme: buildAppTheme(),
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return FileArrivalScope(child: child ?? const SizedBox.shrink());
      },
    );
  }
}
