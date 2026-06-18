import 'package:fileflow/core/models/retention_rule.dart';
import 'package:fileflow/core/providers/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RulesNotifier extends AsyncNotifier<List<RetentionRule>> {
  @override
  Future<List<RetentionRule>> build() async {
    return ref.watch(retentionRuleDaoProvider).getAll();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(retentionRuleDaoProvider).getAll(),
    );
  }

  Future<void> addRule(RetentionRule rule) async {
    await ref.read(retentionRuleDaoProvider).insert(rule);
    await refresh();
  }

  Future<void> updateRule(RetentionRule rule) async {
    await ref.read(retentionRuleDaoProvider).update(rule);
    await refresh();
  }

  Future<void> deleteRule(int id) async {
    await ref.read(retentionRuleDaoProvider).delete(id);
    await refresh();
  }

  Future<void> toggleEnabled(int id, {required bool enabled}) async {
    await ref.read(retentionRuleDaoProvider).setEnabled(id, enabled: enabled);
    await refresh();
  }
}

final rulesProvider =
    AsyncNotifierProvider<RulesNotifier, List<RetentionRule>>(
      RulesNotifier.new,
    );
