import 'package:fileflow/core/models/deletion_log_entry.dart';
import 'package:fileflow/core/providers/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DailyDeletionStat {
  const DailyDeletionStat({
    required this.date,
    required this.count,
    required this.bytes,
  });

  final DateTime date;
  final int count;
  final int bytes;
}

class StorageAnalytics {
  const StorageAnalytics({
    required this.activeFiles,
    required this.deletedThisMonth,
    required this.spaceReclaimedBytes,
    required this.spaceReclaimedThisMonthBytes,
    required this.expiringSoonCount,
    required this.starredCount,
    required this.last7Days,
  });

  final int activeFiles;
  final int deletedThisMonth;
  final int spaceReclaimedBytes;
  final int spaceReclaimedThisMonthBytes;
  final int expiringSoonCount;
  final int starredCount;
  final List<DailyDeletionStat> last7Days;
}

class AnalyticsNotifier extends AsyncNotifier<StorageAnalytics> {
  @override
  Future<StorageAnalytics> build() async {
    return _load();
  }

  Future<StorageAnalytics> _load() async {
    final fileDao = ref.read(trackedFileDaoProvider);
    final logDao = ref.read(deletionLogDaoProvider);

    final results = await Future.wait([
      fileDao.countActive(),
      logDao.countThisMonth(),
      logDao.totalSpaceReclaimed(),
      logDao.spaceReclaimedThisMonth(),
      fileDao.getExpiringSoon(withinDays: 7),
      fileDao.getStarred(),
      logDao.getRecentEntries(days: 7),
    ]);

    final recentEntries = results[6] as List<DeletionLogEntry>;
    final last7Days = _buildDailyStats(recentEntries);

    return StorageAnalytics(
      activeFiles: results[0] as int,
      deletedThisMonth: results[1] as int,
      spaceReclaimedBytes: results[2] as int,
      spaceReclaimedThisMonthBytes: results[3] as int,
      expiringSoonCount: (results[4] as List).length,
      starredCount: (results[5] as List).length,
      last7Days: last7Days,
    );
  }

  List<DailyDeletionStat> _buildDailyStats(List<DeletionLogEntry> entries) {
    final now = DateTime.now();

    // Group entries by local calendar day
    final byDay = <DateTime, ({int count, int bytes})>{};
    for (final entry in entries) {
      final day = DateTime(
        entry.deletedAt.year,
        entry.deletedAt.month,
        entry.deletedAt.day,
      );
      final existing = byDay[day] ?? (count: 0, bytes: 0);
      byDay[day] = (
        count: existing.count + 1,
        bytes: existing.bytes + entry.size,
      );
    }

    // Generate a complete 7-day window (oldest first)
    final stats = <DailyDeletionStat>[];
    for (var i = 6; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: i));
      final data = byDay[date] ?? (count: 0, bytes: 0);
      stats.add(
        DailyDeletionStat(date: date, count: data.count, bytes: data.bytes),
      );
    }

    return stats;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }
}

final analyticsProvider =
    AsyncNotifierProvider<AnalyticsNotifier, StorageAnalytics>(
      AnalyticsNotifier.new,
    );
