import 'package:fileflow/core/background/workmanager_tasks.dart';
import 'package:fileflow/core/providers/files_provider.dart';
import 'package:fileflow/core/theme/app_theme.dart';
import 'package:fileflow/features/files/widgets/file_card.dart';
import 'package:fileflow/shared/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FilesScreen extends ConsumerWidget {
  const FilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filesAsync = ref.watch(filesProvider);
    final notifier = ref.read(filesProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Files'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
            tooltip: 'Scan now',
            onPressed: () async {
              await WorkManagerTasks.runCleanupNow();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Background scan queued'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
              await notifier.refresh();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(
            currentFilter: notifier.currentFilter,
            onChanged: notifier.setFilter,
          ),
          Expanded(
            child: filesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: AppColors.accent,
                  strokeWidth: 2,
                ),
              ),
              error: (err, _) => EmptyState(
                icon: Icons.error_outline,
                title: 'Something went wrong',
                subtitle: err.toString(),
                action: notifier.refresh,
                actionLabel: 'Retry',
              ),
              data: (files) {
                if (files.isEmpty) {
                  return _emptyForFilter(notifier.currentFilter, notifier);
                }
                return RefreshIndicator(
                  color: AppColors.accent,
                  onRefresh: notifier.refresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 24),
                    itemCount: files.length,
                    itemBuilder: (_, i) => FileCard(file: files[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyForFilter(FilesFilter filter, FilesNotifier notifier) {
    return switch (filter) {
      FilesFilter.all => EmptyState(
        icon: Icons.folder_open_outlined,
        title: 'No files tracked yet',
        subtitle: 'FileFlow will detect files in your monitored folders.',
        action: notifier.refresh,
        actionLabel: 'Refresh',
      ),
      FilesFilter.starred => const EmptyState(
        icon: Icons.star_border_rounded,
        title: 'No starred files',
        subtitle: 'Star files to keep them forever.',
      ),
      FilesFilter.expiringSoon => const EmptyState(
        icon: Icons.timer_outlined,
        title: 'Nothing expiring soon',
        subtitle: 'All clear — no files expiring within 7 days.',
      ),
    };
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.currentFilter,
    required this.onChanged,
  });

  final FilesFilter currentFilter;
  final void Function(FilesFilter) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _Chip(
            label: 'All',
            isSelected: currentFilter == FilesFilter.all,
            onTap: () => onChanged(FilesFilter.all),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: '⭐ Starred',
            isSelected: currentFilter == FilesFilter.starred,
            onTap: () => onChanged(FilesFilter.starred),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: '⏳ Expiring',
            isSelected: currentFilter == FilesFilter.expiringSoon,
            onTap: () => onChanged(FilesFilter.expiringSoon),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accent.withValues(alpha: 0.15)
              : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.cardBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color:
                isSelected ? AppColors.accent : AppColors.textSecondary,
            fontSize: 13,
            fontWeight:
                isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
