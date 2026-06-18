import 'package:fileflow/core/background/workmanager_tasks.dart';
import 'package:fileflow/core/models/monitored_folder.dart';
import 'package:fileflow/core/providers/folders_provider.dart';
import 'package:fileflow/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;
  bool _storageGranted = false;
  bool _notifGranted = false;

  final _defaultFolders = [
    ('Screenshots', '/storage/emulated/0/DCIM/Screenshots', 7),
    ('Downloads', '/storage/emulated/0/Download', 30),
    ('WhatsApp Images', '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images', 14),
    ('WhatsApp Videos', '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Video', 14),
    ('Telegram', '/storage/emulated/0/Telegram', 30),
    ('Documents', '/storage/emulated/0/Documents', 0),
    ('Camera', '/storage/emulated/0/DCIM/Camera', 0),
  ];

  final _selectedFolders = <int>{0, 1};

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_page < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _ProgressBar(current: _page, total: 4),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _WelcomePage(onNext: _nextPage),
                  _PermissionsPage(
                    storageGranted: _storageGranted,
                    notifGranted: _notifGranted,
                    onRequestStorage: _requestStorage,
                    onRequestNotif: _requestNotif,
                    onNext: _nextPage,
                  ),
                  _FolderSelectionPage(
                    folders: _defaultFolders,
                    selected: _selectedFolders,
                    onToggle: (i) =>
                        setState(() => _selectedFolders.contains(i)
                            ? _selectedFolders.remove(i)
                            : _selectedFolders.add(i)),
                    onNext: _nextPage,
                  ),
                  _FinishPage(onFinish: _finish),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestStorage() async {
    final status = await Permission.manageExternalStorage.request();
    setState(() => _storageGranted = status.isGranted);
  }

  Future<void> _requestNotif() async {
    final status = await Permission.notification.request();
    setState(() => _notifGranted = status.isGranted);
  }

  Future<void> _finish() async {
    for (final index in _selectedFolders) {
      final (name, path, days) = _defaultFolders[index];
      await ref.read(foldersProvider.notifier).addFolder(
        MonitoredFolder(
          id: 0,
          path: path,
          displayName: name,
          isEnabled: true,
          defaultRetentionDays: days,
          createdAt: DateTime.now(),
        ),
      );
    }

    await WorkManagerTasks.registerDailyCleanup();
    await WorkManagerTasks.registerPeriodicScan();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);

    if (mounted) context.go('/');
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: List.generate(
          total,
          (i) => Expanded(
            child: Container(
              height: 3,
              margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
              decoration: BoxDecoration(
                color: i <= current ? AppColors.accent : AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.onNext});
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.accent, Color(0xFF4A44B3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.auto_delete_outlined,
              color: Colors.white,
              size: 48,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'FileFlow',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.5,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Keep what matters.\nDelete the rest.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 18,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onNext,
              child: const Text('Get started'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionsPage extends StatelessWidget {
  const _PermissionsPage({
    required this.storageGranted,
    required this.notifGranted,
    required this.onRequestStorage,
    required this.onRequestNotif,
    required this.onNext,
  });

  final bool storageGranted;
  final bool notifGranted;
  final VoidCallback onRequestStorage;
  final VoidCallback onRequestNotif;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text(
            'Permissions',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'FileFlow needs these to monitor and clean your files.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
          ),
          const SizedBox(height: 32),
          _PermissionTile(
            icon: Icons.storage_outlined,
            title: 'Storage access',
            subtitle: 'Monitor Downloads, Screenshots & WhatsApp media.',
            granted: storageGranted,
            onRequest: onRequestStorage,
          ),
          const SizedBox(height: 12),
          _PermissionTile(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Get notified when files are cleaned up.',
            granted: notifGranted,
            onRequest: onRequestNotif,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: storageGranted ? onNext : null,
              child: const Text('Continue'),
            ),
          ),
          const SizedBox(height: 8),
          if (!storageGranted)
            const Center(
              child: Text(
                'Storage access is required to continue',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.onRequest,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool granted;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: granted
              ? AppColors.safe.withValues(alpha: 0.4)
              : AppColors.cardBorder,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: granted ? AppColors.safe : AppColors.textSecondary,
            size: 22,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (granted)
            const Icon(Icons.check_circle, color: AppColors.safe, size: 22)
          else
            TextButton(
              onPressed: onRequest,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text('Grant'),
            ),
        ],
      ),
    );
  }
}

class _FolderSelectionPage extends StatelessWidget {
  const _FolderSelectionPage({
    required this.folders,
    required this.selected,
    required this.onToggle,
    required this.onNext,
  });

  final List<(String, String, int)> folders;
  final Set<int> selected;
  final void Function(int) onToggle;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text(
            'Pick folders to monitor',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'FileFlow will track new files in these folders.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: folders.length,
              itemBuilder: (_, i) {
                final (name, _, days) = folders[i];
                final isSelected = selected.contains(i);
                return GestureDetector(
                  onTap: () => onToggle(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.accent.withValues(alpha: 0.1)
                          : AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.accent
                            : AppColors.cardBorder,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.folder_outlined,
                          color: isSelected
                              ? AppColors.accent
                              : AppColors.textMuted,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: TextStyle(
                                  color: isSelected
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                days == 0
                                    ? 'Never delete'
                                    : 'Delete after $days days',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_circle,
                            color: AppColors.accent,
                            size: 18,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: selected.isNotEmpty ? onNext : null,
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FinishPage extends StatelessWidget {
  const _FinishPage({required this.onFinish});
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.safe.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.safe.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.check, color: AppColors.safe, size: 44),
          ),
          const SizedBox(height: 28),
          const Text(
            "You're all set!",
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'FileFlow will automatically track and clean your files in the background.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _FeatureRow(
            icon: Icons.auto_delete_outlined,
            text: 'Files auto-deleted on your schedule',
          ),
          _FeatureRow(
            icon: Icons.star_border_rounded,
            text: 'Star important files to keep forever',
          ),
          _FeatureRow(
            icon: Icons.shield_outlined,
            text: 'Rules protect what should never be deleted',
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onFinish,
              child: const Text('Start using FileFlow'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accent, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
