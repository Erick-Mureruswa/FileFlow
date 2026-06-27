import 'package:fileflow/core/models/tracked_file.dart';
import 'package:fileflow/core/providers/swipe_cleanup_provider.dart';
import 'package:fileflow/core/theme/app_theme.dart';
import 'package:fileflow/shared/utils/file_utils.dart';
import 'package:fileflow/shared/widgets/file_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class SwipeCleanupScreen extends ConsumerWidget {
  const SwipeCleanupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(swipeCleanupProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Swipe Cleanup'),
        actions: [
          async.valueOrNull.let((s) {
            final count = s?.pendingDeletions.length ?? 0;
            if (count == 0) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Badge(
                label: Text('$count'),
                backgroundColor: AppColors.danger,
                child: IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined),
                  color: AppColors.danger,
                  tooltip: 'Review deletion queue',
                  onPressed: () => context.push('/batch-deletion'),
                ),
              ),
            );
          }),
        ],
      ),
      body: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: AppColors.accent,
            strokeWidth: 2,
          ),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppColors.danger, size: 48),
              const SizedBox(height: 12),
              Text(
                e.toString(),
                style: const TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () =>
                    ref.read(swipeCleanupProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (state) => _SwipeCleanupBody(state: state),
      ),
    );
  }
}

class _SwipeCleanupBody extends ConsumerWidget {
  const _SwipeCleanupBody({required this.state});
  final SwipeCleanupState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final files = state.reviewFiles;

    if (files.isEmpty) {
      return _EmptyState(hasPending: state.pendingDeletions.isNotEmpty);
    }

    return Column(
      children: [
        _ProgressHeader(
          remaining: files.length,
          pending: state.pendingDeletions.length,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _CardStack(files: files),
          ),
        ),
        _HintRow(),
        _ActionButtons(topFile: files.first),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.remaining, required this.pending});
  final int remaining;
  final int pending;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      child: Row(
        children: [
          Text(
            '$remaining files to review',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          if (pending > 0)
            GestureDetector(
              onTap: () => GoRouter.of(context).push('/batch-deletion'),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.delete_outline,
                        color: AppColors.danger, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      '$pending queued',
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CardStack extends StatelessWidget {
  const _CardStack({required this.files});
  final List<TrackedFile> files;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        if (files.length > 2)
          Positioned.fill(
            top: 16,
            child: Transform.scale(
              scale: 0.92,
              alignment: Alignment.topCenter,
              child: _StaticFileCard(file: files[2]),
            ),
          ),
        if (files.length > 1)
          Positioned.fill(
            top: 8,
            child: Transform.scale(
              scale: 0.96,
              alignment: Alignment.topCenter,
              child: _StaticFileCard(file: files[1]),
            ),
          ),
        Positioned.fill(
          child: Consumer(
            builder: (context, ref, _) => _DraggableCard(
              key: ValueKey(files[0].id),
              file: files[0],
              onSwipe: (keep) {
                if (keep) {
                  ref.read(swipeCleanupProvider.notifier).keepFile(files[0]);
                } else {
                  ref
                      .read(swipeCleanupProvider.notifier)
                      .queueForDeletion(files[0]);
                  _showUndoSnackbar(context, ref, files[0]);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  void _showUndoSnackbar(
    BuildContext context,
    WidgetRef ref,
    TrackedFile file,
  ) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        content: Text(
          '${file.name} queued for deletion',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        action: SnackBarAction(
          label: 'Undo',
          textColor: AppColors.accent,
          onPressed: () =>
              ref.read(swipeCleanupProvider.notifier).undoDelete(file),
        ),
      ),
    );
  }
}

class _HintRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.arrow_back, color: AppColors.danger, size: 16),
              const SizedBox(width: 4),
              Text(
                'DELETE',
                style: TextStyle(
                  color: AppColors.danger.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                'KEEP',
                style: TextStyle(
                  color: AppColors.safe.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward, color: AppColors.safe, size: 16),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButtons extends ConsumerWidget {
  const _ActionButtons({required this.topFile});
  final TrackedFile topFile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _CircleButton(
            icon: Icons.close,
            color: AppColors.danger,
            onTap: () {
              ref
                  .read(swipeCleanupProvider.notifier)
                  .queueForDeletion(topFile);
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  duration: const Duration(seconds: 5),
                  content: Text(
                    '${topFile.name} queued for deletion',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  action: SnackBarAction(
                    label: 'Undo',
                    textColor: AppColors.accent,
                    onPressed: () => ref
                        .read(swipeCleanupProvider.notifier)
                        .undoDelete(topFile),
                  ),
                ),
              );
            },
          ),
          _CircleButton(
            icon: Icons.favorite,
            color: AppColors.safe,
            onTap: () =>
                ref.read(swipeCleanupProvider.notifier).keepFile(topFile),
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.08),
          border: Border.all(color: color, width: 2),
        ),
        child: Icon(icon, color: color, size: 30),
      ),
    );
  }
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState({required this.hasPending});
  final bool hasPending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (hasPending) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.delete_sweep_outlined,
                color: AppColors.danger,
                size: 72,
              ),
              const SizedBox(height: 20),
              const Text(
                'Review complete',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'You\'ve reviewed all files.\nConfirm which ones to delete.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: () => context.push('/batch-deletion'),
                icon: const Icon(Icons.delete_forever_outlined, size: 18),
                label: const Text('Review Deletion Queue'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () =>
                    ref.read(swipeCleanupProvider.notifier).refresh(),
                child: const Text('Refresh files'),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: AppColors.safe,
              size: 72,
            ),
            const SizedBox(height: 20),
            const Text(
              'All Clean!',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'No unreviewed files in your monitored folders.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            OutlinedButton.icon(
              onPressed: () =>
                  ref.read(swipeCleanupProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Draggable Card ─────────────────────────────────────────────────────────

class _DraggableCard extends StatefulWidget {
  const _DraggableCard({
    super.key,
    required this.file,
    required this.onSwipe,
  });

  final TrackedFile file;
  final void Function(bool keep) onSwipe;

  @override
  State<_DraggableCard> createState() => _DraggableCardState();
}

class _DraggableCardState extends State<_DraggableCard>
    with SingleTickerProviderStateMixin {
  static const _threshold = 120.0;

  late final AnimationController _ctrl;
  late Animation<Offset> _anim;
  Offset _offset = Offset.zero;
  bool _isFlying = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this);
    _anim = _ctrl.drive(Tween(begin: Offset.zero, end: Offset.zero));
    _ctrl.addListener(() {
      if (mounted) setState(() => _offset = _anim.value);
    });
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && _isFlying && mounted) {
        widget.onSwipe(_offset.dx > 0);
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails _) => _ctrl.stop();

  void _onPanUpdate(DragUpdateDetails d) {
    if (_ctrl.isAnimating) return;
    setState(() => _offset += d.delta);
  }

  void _onPanEnd(DragEndDetails _) {
    if (_offset.dx.abs() > _threshold) {
      _isFlying = true;
      final target = Offset(_offset.dx.sign * 700, _offset.dy + 40);
      _anim = Tween<Offset>(begin: _offset, end: target).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
      );
      _ctrl
        ..duration = const Duration(milliseconds: 220)
        ..reset()
        ..forward();
      HapticFeedback.mediumImpact();
    } else {
      _isFlying = false;
      _anim = Tween<Offset>(begin: _offset, end: Offset.zero).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
      );
      _ctrl
        ..duration = const Duration(milliseconds: 500)
        ..reset()
        ..forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final angle = (_offset.dx / 1400).clamp(-0.25, 0.25);
    final keepOpacity = (_offset.dx / _threshold).clamp(0.0, 1.0);
    final deleteOpacity = (-_offset.dx / _threshold).clamp(0.0, 1.0);

    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Transform.translate(
        offset: _offset,
        child: Transform.rotate(
          angle: angle,
          alignment: Alignment.bottomCenter,
          child: Stack(
            children: [
              _FileCard(file: widget.file),
              if (keepOpacity > 0.05)
                _SwipeOverlay(
                  label: 'KEEP',
                  color: AppColors.safe,
                  icon: Icons.favorite,
                  opacity: keepOpacity,
                  alignment: Alignment.topLeft,
                ),
              if (deleteOpacity > 0.05)
                _SwipeOverlay(
                  label: 'DELETE',
                  color: AppColors.danger,
                  icon: Icons.delete_outline,
                  opacity: deleteOpacity,
                  alignment: Alignment.topRight,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwipeOverlay extends StatelessWidget {
  const _SwipeOverlay({
    required this.label,
    required this.color,
    required this.icon,
    required this.opacity,
    required this.alignment,
  });

  final String label;
  final Color color;
  final IconData icon;
  final double opacity;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Opacity(
            opacity: opacity,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color, width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── File Cards ─────────────────────────────────────────────────────────────

class _StaticFileCard extends StatelessWidget {
  const _StaticFileCard({required this.file});
  final TrackedFile file;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
    );
  }
}

class _FileCard extends StatelessWidget {
  const _FileCard({required this.file});
  final TrackedFile file;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 6,
              child: FileThumbnail(
                path: file.path,
                type: file.fileType,
                expand: true,
              ),
            ),
            _FileInfo(file: file),
          ],
        ),
      ),
    );
  }
}

class _FileInfo extends StatelessWidget {
  const _FileInfo({required this.file});
  final TrackedFile file;

  String get _parentFolder {
    final parts = file.path.split('/');
    return parts.length >= 2
        ? parts[parts.length - 2]
        : file.path;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            file.name,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.folder_outlined,
                  color: AppColors.textMuted, size: 13),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _parentFolder,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _InfoChip(
                label: FileUtils.formatSize(file.size),
                icon: Icons.data_usage_outlined,
                color: AppColors.accent,
              ),
              const SizedBox(width: 8),
              _InfoChip(
                label: DateFormat('MMM d, yyyy').format(file.detectedAt),
                icon: Icons.calendar_today_outlined,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.icon,
    required this.color,
  });
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ─── Extension helper ────────────────────────────────────────────────────────

extension _LetExt<T> on T {
  R let<R>(R Function(T) block) => block(this);
}
