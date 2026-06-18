import 'package:fileflow/core/models/tracked_file.dart';
import 'package:fileflow/core/providers/database_provider.dart';
import 'package:fileflow/core/services/deletion_service.dart';
import 'package:fileflow/core/services/file_scanner_service.dart';
import 'package:fileflow/core/services/rule_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum FilesFilter { all, starred, expiringSoon }

class FilesNotifier extends AsyncNotifier<List<TrackedFile>> {
  FilesFilter _filter = FilesFilter.all;

  FilesFilter get currentFilter => _filter;

  @override
  Future<List<TrackedFile>> build() async {
    return _loadFiles();
  }

  Future<List<TrackedFile>> _loadFiles() {
    final dao = ref.read(trackedFileDaoProvider);
    return switch (_filter) {
      FilesFilter.all => dao.getAll(),
      FilesFilter.starred => dao.getStarred(),
      FilesFilter.expiringSoon => dao.getExpiringSoon(),
    };
  }

  Future<void> setFilter(FilesFilter filter) async {
    _filter = filter;
    state = const AsyncLoading();
    state = await AsyncValue.guard(_loadFiles);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_loadFiles);
  }

  Future<void> toggleStar(TrackedFile file) async {
    final dao = ref.read(trackedFileDaoProvider);
    await dao.setStarred(file.id, starred: !file.isStarred);
    await refresh();
  }

  Future<void> setExpiry(TrackedFile file, DateTime? expiresAt) async {
    final dao = ref.read(trackedFileDaoProvider);
    await dao.setExpiry(file.id, expiresAt);
    await refresh();
  }

  Future<void> deleteFile(TrackedFile file) async {
    final ruleEngine = const RuleEngine();
    final service = DeletionService(
      ref.read(trackedFileDaoProvider),
      ref.read(retentionRuleDaoProvider),
      ref.read(deletionLogDaoProvider),
      ref.read(recycleBinDaoProvider),
      ruleEngine,
    );
    await service.deleteFileNow(file);
    await refresh();
  }
}

final filesProvider =
    AsyncNotifierProvider<FilesNotifier, List<TrackedFile>>(FilesNotifier.new);

// Separate provider for quick scanner runs from the UI
final scannerProvider = Provider<FileScannerService>((ref) {
  return FileScannerService(
    ref.watch(monitoredFolderDaoProvider),
    ref.watch(trackedFileDaoProvider),
    const RuleEngine(),
  );
});
