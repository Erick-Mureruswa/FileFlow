import 'package:fileflow/core/providers/file_arrival_provider.dart';
import 'package:fileflow/core/providers/folders_provider.dart';
import 'package:fileflow/core/services/monitor_control.dart';
import 'package:fileflow/features/file_arrival/widgets/file_arrival_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mounts the real-time folder watcher for the whole app and overlays the smart
/// arrival popup above the current screen.
///
/// - Starts watching once the first frame is up.
/// - Restarts the watcher on app resume (FileObserver does not survive the
///   process being killed) and whenever the monitored-folder set changes.
class FileArrivalScope extends ConsumerStatefulWidget {
  const FileArrivalScope({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<FileArrivalScope> createState() => _FileArrivalScopeState();
}

class _FileArrivalScopeState extends ConsumerState<FileArrivalScope>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(fileArrivalProvider.notifier).startWatching();
      // Start the background service now, while the app is clearly in the
      // foreground (Android forbids starting a foreground service from the
      // background). It stands down while the app is visible and takes over
      // once the app is closed.
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(MonitorControl.prefKey) ?? true) {
        await MonitorControl.start();
        // Ask once for the battery-optimization exemption, without which the
        // OS freezes the service and background tracking stops.
        if (!(prefs.getBool('battery_prompt_shown') ?? false)) {
          if (!await MonitorControl.isBatteryExempt()) {
            await MonitorControl.requestBatteryExemption();
          }
          await prefs.setBool('battery_prompt_shown', true);
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final notifier = ref.read(fileArrivalProvider.notifier);
    if (state == AppLifecycleState.resumed) {
      // Foreground: the in-app popup handles arrivals again. Restarting resets
      // the watermark so files tracked by the service while we were away do not
      // replay as a burst of popups.
      notifier.restart();
    } else if (state == AppLifecycleState.paused) {
      // Background: hand off to the foreground service.
      notifier.stopWatching();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Re-sync the watcher when the user adds/removes/toggles a folder.
    ref.listen(foldersProvider, (previous, next) {
      if (next.hasValue) {
        ref.read(fileArrivalProvider.notifier).restart();
      }
    });

    final arrival = ref.watch(
      fileArrivalProvider.select((state) => state.current),
    );
    final notifier = ref.read(fileArrivalProvider.notifier);

    return Stack(
      children: [
        widget.child,
        if (arrival != null)
          FileArrivalPopup(
            key: ValueKey(arrival.fileId),
            arrival: arrival,
            onStar: notifier.starCurrent,
            onIgnore: notifier.ignoreCurrent,
            onAutoDismiss: notifier.dismissCurrent,
          ),
      ],
    );
  }
}
