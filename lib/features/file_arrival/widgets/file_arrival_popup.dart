import 'package:fileflow/core/models/file_arrival.dart';
import 'package:fileflow/core/models/tracked_file.dart';
import 'package:fileflow/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Smart arrival popup. Appears within a few seconds of a file landing in a
/// monitored folder and offers to protect it. Auto-dismisses after 5 seconds of
/// inactivity (default retention rule already applies in that case).
class FileArrivalPopup extends StatefulWidget {
  const FileArrivalPopup({
    required this.arrival,
    required this.onStar,
    required this.onIgnore,
    required this.onAutoDismiss,
    super.key,
  });

  final FileArrival arrival;
  final VoidCallback onStar;
  final VoidCallback onIgnore;
  final VoidCallback onAutoDismiss;

  @override
  State<FileArrivalPopup> createState() => _FileArrivalPopupState();
}

class _FileArrivalPopupState extends State<FileArrivalPopup>
    with TickerProviderStateMixin {
  static const _timeout = Duration(seconds: 5);

  late final AnimationController _countdown;
  late final AnimationController _entry;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..forward();

    _countdown = AnimationController(vsync: this, duration: _timeout)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_dismissed) {
          _dismissed = true;
          widget.onAutoDismiss();
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    _countdown.dispose();
    _entry.dispose();
    super.dispose();
  }

  void _handle(VoidCallback action) {
    if (_dismissed) return;
    _dismissed = true;
    action();
  }

  @override
  Widget build(BuildContext context) {
    final slide = CurvedAnimation(parent: _entry, curve: Curves.easeOutCubic);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(slide),
          child: FadeTransition(
            opacity: slide,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: _card(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(),
                  const SizedBox(height: 12),
                  _fileRow(),
                  const SizedBox(height: 14),
                  const Text(
                    'Would you like to protect this file?',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _actions(),
                ],
              ),
            ),
            _countdownBar(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.auto_awesome,
            size: 15,
            color: AppColors.accent,
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'New File Detected',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _fileRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.arrival.fileType.icon,
          style: const TextStyle(fontSize: 22),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.arrival.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(
                    Icons.folder_outlined,
                    size: 13,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.arrival.folderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _actions() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _handle(widget.onStar),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.star,
              foregroundColor: const Color(0xFF1A1206),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.star_rounded, size: 18),
            label: const Text('Star File'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _handle(widget.onIgnore),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('Ignore'),
          ),
        ),
      ],
    );
  }

  Widget _countdownBar() {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(16),
        bottomRight: Radius.circular(16),
      ),
      child: AnimatedBuilder(
        animation: _countdown,
        builder: (context, _) {
          return LinearProgressIndicator(
            value: 1 - _countdown.value,
            minHeight: 3,
            backgroundColor: AppColors.cardBorder,
            valueColor: const AlwaysStoppedAnimation(AppColors.accent),
          );
        },
      ),
    );
  }
}
