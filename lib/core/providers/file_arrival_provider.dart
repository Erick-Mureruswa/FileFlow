import 'dart:async';
import 'dart:io';

import 'package:fileflow/core/models/file_arrival.dart';
import 'package:fileflow/core/models/monitored_folder.dart';
import 'package:fileflow/core/providers/database_provider.dart';
import 'package:fileflow/core/providers/files_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State for the smart arrival popup: the arrival currently being shown plus a
/// queue of arrivals waiting their turn (one popup at a time).
class FileArrivalState {
  const FileArrivalState({this.current, this.queue = const []});

  final FileArrival? current;
  final List<FileArrival> queue;
}

class FileArrivalNotifier extends Notifier<FileArrivalState> {
  StreamSubscription<String>? _sub;

  // Cached enabled-folder prefixes for a cheap in-memory guard, so the flood of
  // MediaStore events for files outside monitored folders never touches the DB.
  List<String> _watchedPrefixes = const [];

  @override
  FileArrivalState build() {
    ref.onDispose(() {
      _sub?.cancel();
      _sub = null;
    });
    return const FileArrivalState();
  }

  // Screenshot folder differs by OEM (Samsung → DCIM/Screenshots, Pixel →
  // Pictures/Screenshots). Auto-add whichever exists on disk so screenshots are
  // actually tracked even if onboarding picked the wrong path.
  static const _screenshotCandidates = [
    '/storage/emulated/0/DCIM/Screenshots',
    '/storage/emulated/0/Pictures/Screenshots',
  ];

  /// Begin watching all enabled monitored folders for new files.
  Future<void> startWatching() async {
    await _ensureScreenshotFolders();

    final folderDao = ref.read(monitoredFolderDaoProvider);
    final folders = await folderDao.getEnabled();
    final paths = folders.map((f) => f.path).toList();
    _watchedPrefixes = paths.map((p) => '$p/').toList();

    final watcher = ref.read(fileWatcherServiceProvider);
    // Subscribe first so the native EventChannel sink is registered before any
    // event can fire.
    _sub ??= watcher.fileEvents.listen(_onPath);
    await watcher.start(paths);
  }

  Future<void> _ensureScreenshotFolders() async {
    final dao = ref.read(monitoredFolderDaoProvider);
    for (final path in _screenshotCandidates) {
      if (!Directory(path).existsSync()) continue;
      if (await dao.getByPath(path) != null) continue;
      await dao.insert(
        MonitoredFolder(
          id: 0,
          path: path,
          displayName: 'Screenshots',
          isEnabled: true,
          defaultRetentionDays: 7,
          createdAt: DateTime.now(),
        ),
      );
    }
  }

  Future<void> stopWatching() async {
    await ref.read(fileWatcherServiceProvider).stop();
  }

  /// Re-sync the watcher after a lifecycle resume or a change to the folder set.
  Future<void> restart() async {
    await stopWatching();
    await startWatching();
  }

  Future<void> _onPath(String path) async {
    // Cheap guard: ignore anything outside a monitored folder before any DB work.
    if (!_watchedPrefixes.any(path.startsWith)) return;

    final arrival = await ref.read(fileArrivalServiceProvider).processArrival(
      path,
    );
    if (arrival == null) return;
    _enqueue(arrival);
    // Reflect the newly tracked file in the Files list if it's open.
    unawaited(ref.read(filesProvider.notifier).refresh());
  }

  void _enqueue(FileArrival arrival) {
    if (state.current == null) {
      state = FileArrivalState(current: arrival, queue: state.queue);
    } else {
      state = FileArrivalState(
        current: state.current,
        queue: [...state.queue, arrival],
      );
    }
  }

  void _advance() {
    if (state.queue.isNotEmpty) {
      state = FileArrivalState(
        current: state.queue.first,
        queue: state.queue.sublist(1),
      );
    } else {
      state = const FileArrivalState();
    }
  }

  /// Star File → protect the file (excluded from cleanup) and move on.
  Future<void> starCurrent() async {
    final current = state.current;
    if (current == null) return;
    await ref.read(trackedFileDaoProvider).setStarred(
      current.fileId,
      starred: true,
    );
    unawaited(ref.read(filesProvider.notifier).refresh());
    _advance();
  }

  /// Ignore → keep the default retention rule already applied on arrival.
  void ignoreCurrent() => _advance();

  /// Auto-dismiss after 5s with no action → same as ignore.
  void dismissCurrent() => _advance();
}

final fileArrivalProvider =
    NotifierProvider<FileArrivalNotifier, FileArrivalState>(
      FileArrivalNotifier.new,
    );
