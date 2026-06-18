import 'package:fileflow/core/database/daos/deletion_log_dao.dart';
import 'package:fileflow/core/database/daos/monitored_folder_dao.dart';
import 'package:fileflow/core/database/daos/pending_deletion_dao.dart';
import 'package:fileflow/core/database/daos/recycle_bin_dao.dart';
import 'package:fileflow/core/database/daos/retention_rule_dao.dart';
import 'package:fileflow/core/database/daos/tracked_file_dao.dart';
import 'package:fileflow/core/database/database_helper.dart';
import 'package:fileflow/core/services/deletion_service.dart';
import 'package:fileflow/core/services/file_arrival_service.dart';
import 'package:fileflow/core/services/file_watcher_service.dart';
import 'package:fileflow/core/services/rule_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper.instance;
});

final monitoredFolderDaoProvider = Provider<MonitoredFolderDao>((ref) {
  return MonitoredFolderDao(ref.watch(databaseHelperProvider));
});

final trackedFileDaoProvider = Provider<TrackedFileDao>((ref) {
  return TrackedFileDao(ref.watch(databaseHelperProvider));
});

final retentionRuleDaoProvider = Provider<RetentionRuleDao>((ref) {
  return RetentionRuleDao(ref.watch(databaseHelperProvider));
});

final recycleBinDaoProvider = Provider<RecycleBinDao>((ref) {
  return RecycleBinDao(ref.watch(databaseHelperProvider));
});

final deletionLogDaoProvider = Provider<DeletionLogDao>((ref) {
  return DeletionLogDao(ref.watch(databaseHelperProvider));
});

final pendingDeletionDaoProvider = Provider<PendingDeletionDao>((ref) {
  return PendingDeletionDao(ref.watch(databaseHelperProvider));
});

final ruleEngineProvider = Provider<RuleEngine>((_) => const RuleEngine());

final deletionServiceProvider = Provider<DeletionService>((ref) {
  return DeletionService(
    ref.watch(trackedFileDaoProvider),
    ref.watch(retentionRuleDaoProvider),
    ref.watch(deletionLogDaoProvider),
    ref.watch(recycleBinDaoProvider),
    ref.watch(ruleEngineProvider),
  );
});

final fileWatcherServiceProvider = Provider<FileWatcherService>((_) {
  return FileWatcherService();
});

final fileArrivalServiceProvider = Provider<FileArrivalService>((ref) {
  return FileArrivalService(
    ref.watch(monitoredFolderDaoProvider),
    ref.watch(trackedFileDaoProvider),
    ref.watch(ruleEngineProvider),
  );
});
