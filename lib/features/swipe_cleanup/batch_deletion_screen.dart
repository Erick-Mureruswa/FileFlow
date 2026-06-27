import 'package:fileflow/core/models/tracked_file.dart';
import 'package:fileflow/core/providers/swipe_cleanup_provider.dart';
import 'package:fileflow/core/theme/app_theme.dart';
import 'package:fileflow/shared/utils/file_utils.dart';
import 'package:fileflow/shared/widgets/file_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class BatchDeletionScreen extends ConsumerWidget {
  const BatchDeletionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(swipeCleanupProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Deletion Queue'),
      ),
      body: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2),
        ),
        error: (e, _) => Center(
          child: Text(
            e.toString(),
            style: const TextStyle(color: AppColors.danger),
          ),
        ),
        data: (state) {
          if (state.isProcessingBatch) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                      color: AppColors.danger, strokeWidth: 2),
                  SizedBox(height: 16),
                  Text(
                    'Deleting files…',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }

          final files = state.pendingDeletions;

          if (files.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline,
                      color: AppColors.safe, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'Queue is empty',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'No files are queued for deletion.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back to Cleanup'),
                  ),
                ],
              ),
            );
          }

          final totalSize = files.fold<int>(0, (sum, f) => sum + f.size);

          return Column(
            children: [
              _SummaryHeader(count: files.length, totalBytes: totalSize),
              Expanded(
                child: ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: files.length,
                  itemBuilder: (context, i) => _QueuedFileTile(
                    file: files[i],
                    onRemove: () => ref
                        .read(swipeCleanupProvider.notifier)
                        .removeFromQueue(files[i]),
                  ),
                ),
              ),
              _BottomActions(files: files, totalBytes: totalSize),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.count, required this.totalBytes});
  final int count;
  final int totalBytes;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.delete_forever_outlined,
              color: AppColors.danger, size: 32),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count ${count == 1 ? 'file' : 'files'} queued',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${FileUtils.formatSize(totalBytes)} will be freed',
                style: const TextStyle(
                  color: AppColors.danger,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QueuedFileTile extends StatelessWidget {
  const _QueuedFileTile({required this.file, required this.onRemove});
  final TrackedFile file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
          leading: FileThumbnail(path: file.path, type: file.fileType, size: 44),
          title: Text(
            file.name,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${FileUtils.formatSize(file.size)} · ${DateFormat('MMM d').format(file.detectedAt)}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.restore_outlined,
                color: AppColors.textSecondary, size: 20),
            tooltip: 'Restore (keep)',
            onPressed: onRemove,
          ),
        ),
      ),
    );
  }
}

class _BottomActions extends ConsumerWidget {
  const _BottomActions({required this.files, required this.totalBytes});
  final List<TrackedFile> files;
  final int totalBytes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomPad),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                ref.read(swipeCleanupProvider.notifier).restoreAll();
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.restore_outlined, size: 18),
              label: const Text('Keep All'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _confirmDelete(context, ref),
              icon: const Icon(Icons.delete_forever_outlined, size: 18),
              label: const Text('Delete All'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Permanently delete?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'This will permanently delete ${files.length} ${files.length == 1 ? 'file' : 'files'} '
          '(${FileUtils.formatSize(totalBytes)}). '
          'This action cannot be undone.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(swipeCleanupProvider.notifier).confirmBatchDelete();
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}
