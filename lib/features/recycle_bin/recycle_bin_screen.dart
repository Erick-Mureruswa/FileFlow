import 'package:fileflow/core/models/recycle_bin_item.dart';
import 'package:fileflow/core/providers/recycle_bin_provider.dart';
import 'package:fileflow/core/theme/app_theme.dart';
import 'package:fileflow/shared/utils/file_utils.dart';
import 'package:fileflow/shared/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RecycleBinScreen extends ConsumerWidget {
  const RecycleBinScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(recycleBinProvider);
    final items = itemsAsync.valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Recycle Bin'),
        actions: [
          if (items.isNotEmpty)
            IconButton(
              icon: const Icon(
                Icons.delete_sweep_outlined,
                color: AppColors.danger,
              ),
              tooltip: 'Clear all',
              onPressed: () => _confirmClearAll(context, ref),
            ),
        ],
      ),
      body: itemsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: AppColors.accent,
            strokeWidth: 2,
          ),
        ),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load recycle bin',
          subtitle: e.toString(),
          action: () => ref.read(recycleBinProvider.notifier).refresh(),
          actionLabel: 'Retry',
        ),
        data: (itemList) {
          if (itemList.isEmpty) {
            return const EmptyState(
              icon: Icons.delete_outline_rounded,
              title: 'Recycle bin is empty',
              subtitle:
                  'Auto-deleted files appear here until their records expire.',
            );
          }
          return Column(
            children: [
              _SummaryBanner(items: itemList),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.accent,
                  onRefresh: () =>
                      ref.read(recycleBinProvider.notifier).refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 24),
                    itemCount: itemList.length,
                    itemBuilder: (_, i) =>
                        _RecycleBinItemCard(item: itemList[i]),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        title: const Text(
          'Clear recycle bin?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'All deletion records will be removed. This cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(recycleBinProvider.notifier).clearAll();
    }
  }
}

class _SummaryBanner extends StatelessWidget {
  const _SummaryBanner({required this.items});
  final List<RecycleBinItem> items;

  @override
  Widget build(BuildContext context) {
    final totalSize = items.fold(0, (sum, i) => sum + i.size);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.textMuted, size: 15),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${items.length} record${items.length == 1 ? '' : 's'} · '
              '${FileUtils.formatSize(totalSize)} · '
              'Files are physically deleted on removal',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecycleBinItemCard extends ConsumerWidget {
  const _RecycleBinItemCard({required this.item});
  final RecycleBinItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final daysAgo = now.difference(item.deletedAt).inDays;
    final daysLeft = item.permanentDeleteAt.difference(now).inDays;
    final isExpired = daysLeft <= 0;

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: AppColors.danger.withValues(alpha: 0.12),
        child: const Icon(Icons.remove_circle_outline, color: AppColors.danger),
      ),
      onDismissed: (_) =>
          ref.read(recycleBinProvider.notifier).removeItem(item.id),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 6,
          ),
          leading: _FileTypeIcon(fileType: item.fileType),
          isThreeLine: true,
          title: Text(
            item.name,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 3),
              Text(
                '${FileUtils.formatSize(item.size)} · deleted '
                '${daysAgo == 0 ? 'today' : '$daysAgo day${daysAgo == 1 ? '' : 's'} ago'}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isExpired
                    ? 'Record expired'
                    : 'Record expires in $daysLeft day${daysLeft == 1 ? '' : 's'}',
                style: TextStyle(
                  color: isExpired ? AppColors.danger : AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(
              Icons.remove_circle_outline,
              color: AppColors.textMuted,
              size: 18,
            ),
            onPressed: () =>
                ref.read(recycleBinProvider.notifier).removeItem(item.id),
          ),
        ),
        ),
      ),
    );
  }
}

class _FileTypeIcon extends StatelessWidget {
  const _FileTypeIcon({required this.fileType});
  final String fileType;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (fileType) {
      'image' => (Icons.image_outlined, const Color(0xFF6366F1)),
      'video' => (Icons.video_file_outlined, const Color(0xFF8B5CF6)),
      'audio' => (Icons.audio_file_outlined, const Color(0xFFEC4899)),
      'document' => (Icons.description_outlined, const Color(0xFF3B82F6)),
      'archive' => (Icons.folder_zip_outlined, AppColors.star),
      _ => (Icons.insert_drive_file_outlined, AppColors.textMuted),
    };

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
