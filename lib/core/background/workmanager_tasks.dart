import 'package:fileflow/core/database/daos/deletion_log_dao.dart';
import 'package:fileflow/core/database/daos/monitored_folder_dao.dart';
import 'package:fileflow/core/database/daos/recycle_bin_dao.dart';
import 'package:fileflow/core/database/daos/retention_rule_dao.dart';
import 'package:fileflow/core/database/daos/tracked_file_dao.dart';
import 'package:fileflow/core/database/database_helper.dart';
import 'package:fileflow/core/services/deletion_service.dart';
import 'package:fileflow/core/services/file_scanner_service.dart';
import 'package:fileflow/core/services/notification_service.dart';
import 'package:fileflow/core/services/rule_engine.dart';
import 'package:workmanager/workmanager.dart';

const _taskDailyCleanup = 'fileflow.daily_cleanup';
const _taskPeriodicScan = 'fileflow.periodic_scan';

// Top-level callback required by WorkManager — must be a free function.
@pragma('vm:entry-point')
void workmanagerCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    switch (taskName) {
      case _taskDailyCleanup:
        await _runDailyCleanup();
      case _taskPeriodicScan:
        await _runPeriodicScan();
    }
    return true;
  });
}

Future<void> _runDailyCleanup() async {
  final db = DatabaseHelper.instance;
  final ruleEngine = const RuleEngine();

  final scanner = FileScannerService(
    MonitoredFolderDao(db),
    TrackedFileDao(db),
    ruleEngine,
  );

  final deleter = DeletionService(
    TrackedFileDao(db),
    RetentionRuleDao(db),
    DeletionLogDao(db),
    RecycleBinDao(db),
    ruleEngine,
  );

  await scanner.scanAll();
  await scanner.reconcile();
  final result = await deleter.deleteExpired();

  if (result.deletedCount > 0) {
    await NotificationService.instance.showCleanupComplete(
      deletedCount: result.deletedCount,
      bytesFreed: result.bytesFreed,
    );
  }
}

Future<void> _runPeriodicScan() async {
  final db = DatabaseHelper.instance;
  final ruleEngine = const RuleEngine();
  final fileDao = TrackedFileDao(db);
  final scanner = FileScannerService(
    MonitoredFolderDao(db),
    fileDao,
    ruleEngine,
  );
  await scanner.scanAll();

  final expiring = await fileDao.getExpiringSoon(withinDays: 1);
  if (expiring.isNotEmpty) {
    await NotificationService.instance.showFilesExpiringSoon(expiring.length);
  }
}

class WorkManagerTasks {
  WorkManagerTasks._();

  static Future<void> init() async {
    await Workmanager().initialize(workmanagerCallbackDispatcher);
  }

  static Future<void> registerDailyCleanup() async {
    await Workmanager().registerPeriodicTask(
      _taskDailyCleanup,
      _taskDailyCleanup,
      frequency: const Duration(hours: 24),
      constraints: Constraints(
        networkType: NetworkType.notRequired,
        requiresBatteryNotLow: true,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  static Future<void> registerPeriodicScan() async {
    await Workmanager().registerPeriodicTask(
      _taskPeriodicScan,
      _taskPeriodicScan,
      frequency: const Duration(hours: 6),
      constraints: Constraints(networkType: NetworkType.notRequired),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  static Future<void> cancelAll() async {
    await Workmanager().cancelAll();
  }

  static Future<void> runCleanupNow() async {
    await Workmanager().registerOneOffTask(
      '${_taskDailyCleanup}_manual',
      _taskDailyCleanup,
    );
  }
}
