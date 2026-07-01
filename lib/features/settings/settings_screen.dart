import 'package:fileflow/core/background/workmanager_tasks.dart';
import 'package:fileflow/core/services/folder_picker_service.dart';
import 'package:fileflow/core/services/monitor_control.dart';
import 'package:fileflow/core/services/notification_service.dart';
import 'package:fileflow/core/models/monitored_folder.dart';
import 'package:fileflow/core/providers/folders_provider.dart';
import 'package:fileflow/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _recycleBinEnabled = true;
  int _recycleBinDays = 7;
  bool _bgMonitorEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recycleBinEnabled = prefs.getBool('recycle_bin_enabled') ?? true;
      _recycleBinDays = prefs.getInt('recycle_bin_days') ?? 7;
      _bgMonitorEnabled = prefs.getBool(MonitorControl.prefKey) ?? true;
    });
  }

  Future<void> _setBgMonitor(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(MonitorControl.prefKey, v);
    if (v) {
      await MonitorControl.start();
      if (!await MonitorControl.isBatteryExempt()) {
        await MonitorControl.requestBatteryExemption();
      }
    } else {
      await MonitorControl.stop();
    }
    setState(() => _bgMonitorEnabled = v);
  }

  @override
  Widget build(BuildContext context) {
    final foldersAsync = ref.watch(foldersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(label: 'Monitored Folders'),
          const SizedBox(height: 10),
          foldersAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                color: AppColors.accent,
                strokeWidth: 2,
              ),
            ),
            error: (e, _) => Text(
              e.toString(),
              style: const TextStyle(color: AppColors.danger),
            ),
            data: (folders) => Column(
              children: [
                for (final folder in folders)
                  _FolderTile(
                    folder: folder,
                    onToggle: (v) => ref
                        .read(foldersProvider.notifier)
                        .toggleEnabled(folder.id, enabled: v),
                    onDelete: () => ref
                        .read(foldersProvider.notifier)
                        .deleteFolder(folder.id),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _addFolder,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Folder'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader(label: 'Recycle Bin'),
          const SizedBox(height: 10),
          _SettingsTile(
            title: 'Enable recycle bin',
            subtitle: 'Keep deleted files temporarily before permanent removal',
            trailing: Switch(
              value: _recycleBinEnabled,
              onChanged: _setRecycleBinEnabled,
            ),
          ),
          if (_recycleBinEnabled)
            _SettingsTile(
              title: 'Keep for $_recycleBinDays days',
              subtitle: 'Days before permanently removing from recycle bin',
              onTap: _pickRecycleBinDays,
            ),
          _SettingsTile(
            title: 'View recycle bin',
            subtitle: 'Browse recently deleted file records',
            onTap: () => context.push('/recycle-bin'),
          ),
          const SizedBox(height: 24),
          _SectionHeader(label: 'Background Tasks'),
          const SizedBox(height: 10),
          _SettingsTile(
            title: 'Background monitoring',
            subtitle: 'Keep watching folders even when the app is closed',
            trailing: Switch(
              value: _bgMonitorEnabled,
              onChanged: _setBgMonitor,
            ),
          ),
          _SettingsTile(
            title: 'Allow background activity',
            subtitle: 'Stop the system from pausing monitoring to save battery',
            onTap: () async {
              await MonitorControl.requestBatteryExemption();
              if (context.mounted) {
                final exempt = await MonitorControl.isBatteryExempt();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        exempt
                            ? 'Background activity allowed'
                            : 'Still restricted. Allow it to keep monitoring.',
                      ),
                    ),
                  );
                }
              }
            },
          ),
          _SettingsTile(
            title: 'Run cleanup now',
            subtitle: 'Manually trigger a background scan and deletion',
            onTap: () async {
              await WorkManagerTasks.runCleanupNow();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cleanup queued')),
                );
              }
            },
          ),
          const SizedBox(height: 24),
          _SectionHeader(label: 'Permissions'),
          const SizedBox(height: 10),
          _SettingsTile(
            title: 'Storage permission',
            subtitle: 'Required to monitor and delete files',
            onTap: () async {
              final status = await Permission.manageExternalStorage.request();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Permission: ${status.name}')),
                );
              }
            },
          ),
          _SettingsTile(
            title: 'Notification permission',
            subtitle: 'Required for cleanup and expiry alerts (Android 13+)',
            onTap: () async {
              final granted =
                  await NotificationService.instance.requestPermission();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      granted ? 'Notifications enabled' : 'Permission denied',
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _addFolder() async {
    final selectedPath = await FolderPickerService.pickFolder();
    if (selectedPath == null) return;

    if (!mounted) return;
    final days = await _pickFolderRetentionDays();
    if (days == null) return;

    final segments = selectedPath.split('/');
    final displayName =
        segments.lastWhere((s) => s.isNotEmpty, orElse: () => selectedPath);

    await ref.read(foldersProvider.notifier).addFolder(
          MonitoredFolder(
            id: 0,
            path: selectedPath,
            displayName: displayName,
            isEnabled: true,
            defaultRetentionDays: days,
            createdAt: DateTime.now(),
          ),
        );
  }

  Future<int?> _pickFolderRetentionDays() {
    final options = [7, 14, 30, 60, 90];
    return showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Delete files after',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        children: options
            .map(
              (d) => SimpleDialogOption(
                onPressed: () => Navigator.of(ctx).pop(d),
                child: Text(
                  '$d days',
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _setRecycleBinEnabled(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('recycle_bin_enabled', v);
    setState(() => _recycleBinEnabled = v);
  }

  Future<void> _pickRecycleBinDays() async {
    final options = [3, 7, 14, 30];
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Keep for how long?',
            style: TextStyle(color: AppColors.textPrimary)),
        children: options
            .map(
              (d) => SimpleDialogOption(
                onPressed: () => Navigator.of(ctx).pop(d),
                child: Text(
                  '$d days',
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
              ),
            )
            .toList(),
      ),
    );
    if (picked != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('recycle_bin_days', picked);
      setState(() => _recycleBinDays = picked);
    }
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({
    required this.folder,
    required this.onToggle,
    required this.onDelete,
  });

  final MonitoredFolder folder;
  final void Function(bool) onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Icon(
          Icons.folder_outlined,
          color: folder.isEnabled ? AppColors.accent : AppColors.textMuted,
          size: 20,
        ),
        title: Text(
          folder.displayName,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          '${folder.defaultRetentionDays}d retention · ${folder.path}',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(value: folder.isEnabled, onChanged: onToggle),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: AppColors.textMuted, size: 18),
              onPressed: onDelete,
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

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
          onTap: onTap,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          title: Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: subtitle != null
              ? Text(
                  subtitle!,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                )
              : null,
          trailing: trailing ??
              (onTap != null
                  ? const Icon(Icons.chevron_right, color: AppColors.textMuted)
                  : null),
        ),
      ),
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
