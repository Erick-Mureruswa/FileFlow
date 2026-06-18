import 'package:fileflow/core/providers/file_arrival_provider.dart';
import 'package:fileflow/core/providers/folders_provider.dart';
import 'package:fileflow/features/file_arrival/widgets/file_arrival_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(fileArrivalProvider.notifier).startWatching();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(fileArrivalProvider.notifier).restart();
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
