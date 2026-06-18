import 'package:fileflow/core/models/monitored_folder.dart';
import 'package:fileflow/core/providers/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FoldersNotifier extends AsyncNotifier<List<MonitoredFolder>> {
  @override
  Future<List<MonitoredFolder>> build() async {
    return ref.watch(monitoredFolderDaoProvider).getAll();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(monitoredFolderDaoProvider).getAll(),
    );
  }

  Future<void> addFolder(MonitoredFolder folder) async {
    await ref.read(monitoredFolderDaoProvider).insert(folder);
    await refresh();
  }

  Future<void> updateFolder(MonitoredFolder folder) async {
    await ref.read(monitoredFolderDaoProvider).update(folder);
    await refresh();
  }

  Future<void> deleteFolder(int id) async {
    await ref.read(monitoredFolderDaoProvider).delete(id);
    await refresh();
  }

  Future<void> toggleEnabled(int id, {required bool enabled}) async {
    await ref.read(monitoredFolderDaoProvider).setEnabled(id, enabled: enabled);
    await refresh();
  }
}

final foldersProvider =
    AsyncNotifierProvider<FoldersNotifier, List<MonitoredFolder>>(
      FoldersNotifier.new,
    );
