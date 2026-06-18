import 'package:fileflow/core/models/tracked_file.dart';
import 'package:fileflow/core/providers/files_provider.dart';
import 'package:fileflow/core/theme/app_theme.dart';
import 'package:fileflow/features/files/widgets/timer_bottom_sheet.dart';
import 'package:fileflow/shared/utils/file_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FileCard extends ConsumerWidget {
  const FileCard({super.key, required this.file});
  final TrackedFile file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expiryColor = _expiryColor(file);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: file.isStarred
              ? AppColors.star.withValues(alpha: 0.4)
              : AppColors.cardBorder,
          width: file.isStarred ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onLongPress: () => _showDeleteConfirm(context, ref),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // File type icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Center(
                    child: Text(
                      file.fileType.icon,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // File info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            FileUtils.formatSize(file.size),
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (file.isStarred)
                            const Text(
                              '⭐ Kept',
                              style: TextStyle(
                                color: AppColors.star,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            )
                          else
                            Text(
                              FileUtils.formatExpiry(file.expiresAt),
                              style: TextStyle(
                                color: expiryColor,
                                fontSize: 12,
                                fontWeight: file.expiresWithin24Hours
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Actions
                _StarButton(file: file),
                const SizedBox(width: 2),
                _TimerButton(file: file),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _expiryColor(TrackedFile f) {
    if (f.expiresAt == null) return AppColors.textMuted;
    if (f.isExpired) return AppColors.danger;
    if (f.expiresWithin24Hours) return AppColors.danger;
    if (f.expiresWithin7Days) return AppColors.warning;
    return AppColors.textMuted;
  }

  Future<void> _showDeleteConfirm(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Delete file?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'This will permanently delete "${file.name}".',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(filesProvider.notifier).deleteFile(file);
    }
  }
}

class _StarButton extends ConsumerWidget {
  const _StarButton({required this.file});
  final TrackedFile file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      onPressed: () => ref.read(filesProvider.notifier).toggleStar(file),
      icon: Icon(
        file.isStarred ? Icons.star_rounded : Icons.star_border_rounded,
        color: file.isStarred ? AppColors.star : AppColors.textMuted,
        size: 22,
      ),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }
}

class _TimerButton extends ConsumerWidget {
  const _TimerButton({required this.file});
  final TrackedFile file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      onPressed: () => _onTap(context, ref),
      icon: const Icon(
        Icons.timer_outlined,
        color: AppColors.textMuted,
        size: 20,
      ),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }

  Future<void> _onTap(BuildContext context, WidgetRef ref) async {
    final duration = await TimerBottomSheet.show(context, file.name);
    if (duration == null && !context.mounted) return;
    if (context.mounted) {
      final expiresAt = duration != null
          ? DateTime.now().add(duration)
          : null;
      await ref.read(filesProvider.notifier).setExpiry(file, expiresAt);
    }
  }
}
