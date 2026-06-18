import 'package:fileflow/core/models/recycle_bin_item.dart';
import 'package:fileflow/core/providers/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RecycleBinNotifier extends AsyncNotifier<List<RecycleBinItem>> {
  @override
  Future<List<RecycleBinItem>> build() => _load();

  Future<List<RecycleBinItem>> _load() =>
      ref.read(recycleBinDaoProvider).getAll();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<void> removeItem(int id) async {
    await ref.read(recycleBinDaoProvider).delete(id);
    await refresh();
  }

  Future<void> clearAll() async {
    await ref.read(recycleBinDaoProvider).clearAll();
    await refresh();
  }
}

final recycleBinProvider =
    AsyncNotifierProvider<RecycleBinNotifier, List<RecycleBinItem>>(
      RecycleBinNotifier.new,
    );
