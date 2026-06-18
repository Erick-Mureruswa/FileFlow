import 'package:fileflow/core/providers/analytics_provider.dart';
import 'package:fileflow/core/theme/app_theme.dart';
import 'package:fileflow/shared/utils/file_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(analyticsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
            onPressed: () =>
                ref.read(analyticsProvider.notifier).refresh(),
          ),
        ],
      ),
      body: analyticsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: AppColors.accent,
            strokeWidth: 2,
          ),
        ),
        error: (e, _) => Center(
          child: Text(
            e.toString(),
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        data: (stats) => _AnalyticsBody(stats: stats),
      ),
    );
  }
}

class _AnalyticsBody extends StatelessWidget {
  const _AnalyticsBody({required this.stats});
  final StorageAnalytics stats;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(label: 'This Month'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.delete_outline,
                label: 'Files deleted',
                value: stats.deletedThisMonth.toString(),
                color: AppColors.danger,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                icon: Icons.storage_outlined,
                label: 'Space freed',
                value: FileUtils.formatSize(stats.spaceReclaimedThisMonthBytes),
                color: AppColors.safe,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.folder_open_outlined,
                label: 'Active files',
                value: stats.activeFiles.toString(),
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                icon: Icons.star_border_rounded,
                label: 'Starred',
                value: stats.starredCount.toString(),
                color: AppColors.star,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _ActivityChart(stats: stats.last7Days),
        const SizedBox(height: 20),
        _SectionHeader(label: 'All Time'),
        const SizedBox(height: 10),
        _BigStatCard(
          icon: Icons.savings_outlined,
          label: 'Total space reclaimed',
          value: FileUtils.formatSize(stats.spaceReclaimedBytes),
          color: AppColors.safe,
        ),
        const SizedBox(height: 10),
        if (stats.expiringSoonCount > 0)
          _AlertCard(
            message:
                '${stats.expiringSoonCount} file${stats.expiringSoonCount > 1 ? 's' : ''} expiring within 7 days.',
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _BigStatCard extends StatelessWidget {
  const _BigStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_outlined,
              color: AppColors.warning, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.warning,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityChart extends StatelessWidget {
  const _ActivityChart({required this.stats});
  final List<DailyDeletionStat> stats;

  // Total column height: count label(14) + gap(2) + bar area + gap(6) + day label(14)
  static const double _totalHeight = 116;
  static const double _fixedTop = 16; // count label + gap
  static const double _fixedBottom = 20; // gap + day label
  static const double _barAreaHeight =
      _totalHeight - _fixedTop - _fixedBottom; // 80

  @override
  Widget build(BuildContext context) {
    final maxCount = stats.fold(0, (m, s) => s.count > m ? s.count : m);
    final today = DateTime.now();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '7-DAY ACTIVITY',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: _totalHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: stats
                  .map((stat) {
                    final isToday = stat.date.year == today.year &&
                        stat.date.month == today.month &&
                        stat.date.day == today.day;
                    final ratio =
                        maxCount > 0 ? stat.count / maxCount : 0.0;
                    return Expanded(
                      child: _BarColumn(
                        ratio: ratio,
                        count: stat.count,
                        label: DateFormat('E')
                            .format(stat.date)
                            .substring(0, 2),
                        isToday: isToday,
                        barAreaHeight: _barAreaHeight,
                      ),
                    );
                  })
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarColumn extends StatelessWidget {
  const _BarColumn({
    required this.ratio,
    required this.count,
    required this.label,
    required this.isToday,
    required this.barAreaHeight,
  });

  final double ratio;
  final int count;
  final String label;
  final bool isToday;
  final double barAreaHeight;

  @override
  Widget build(BuildContext context) {
    final barHeight = ratio > 0
        ? (barAreaHeight * ratio).clamp(4.0, barAreaHeight)
        : 2.0;

    return Column(
      children: [
        // Fixed-height count label area (always reserved)
        SizedBox(
          height: 14,
          child: count > 0
              ? Text(
                  count.toString(),
                  style: TextStyle(
                    color: isToday
                        ? AppColors.accent
                        : AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                )
              : null,
        ),
        const SizedBox(height: 2),
        // Bar area — bar is bottom-anchored
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: barHeight,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: isToday
                    ? AppColors.accent
                    : (ratio > 0
                        ? AppColors.accent.withValues(alpha: 0.35)
                        : AppColors.cardBorder),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Day label
        Text(
          label,
          style: TextStyle(
            color: isToday ? AppColors.accent : AppColors.textMuted,
            fontSize: 11,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.normal,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
