import 'package:fileflow/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class TimerOption {
  const TimerOption({required this.label, this.duration});
  final String label;
  final Duration? duration;
}

final _timerOptions = [
  const TimerOption(label: '1 hour', duration: Duration(hours: 1)),
  const TimerOption(label: '1 day', duration: Duration(days: 1)),
  const TimerOption(label: '3 days', duration: Duration(days: 3)),
  const TimerOption(label: '7 days', duration: Duration(days: 7)),
  const TimerOption(label: '30 days', duration: Duration(days: 30)),
  const TimerOption(label: '90 days', duration: Duration(days: 90)),
  const TimerOption(label: 'Never delete', duration: null),
];

class TimerBottomSheet extends StatelessWidget {
  const TimerBottomSheet({super.key, required this.fileName});

  final String fileName;

  static Future<Duration?> show(
    BuildContext context,
    String fileName,
  ) async {
    return showModalBottomSheet<Duration?>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => TimerBottomSheet(fileName: fileName),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Row(
              children: [
                const Icon(
                  Icons.timer_outlined,
                  color: AppColors.accent,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Set delete timer',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Text(
              fileName,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Divider(height: 1),
          for (final option in _timerOptions)
            InkWell(
              onTap: () => Navigator.of(context).pop(option.duration),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Text(
                  option.label,
                  style: TextStyle(
                    color: option.duration == null
                        ? AppColors.safe
                        : AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
