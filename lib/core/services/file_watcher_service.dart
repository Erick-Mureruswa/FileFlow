import 'package:flutter/services.dart';

/// Thin wrapper over the native FileObserver watcher.
///
/// `start`/`stop` control which directories are watched; [fileEvents] streams
/// the absolute path of each newly arrived (complete) file in real time while
/// the app process is alive.
class FileWatcherService {
  static const _method = MethodChannel('fileflow/file_watcher');
  static const _events = EventChannel('fileflow/file_watcher_events');

  Stream<String>? _stream;

  Stream<String> get fileEvents {
    return _stream ??= _events
        .receiveBroadcastStream()
        .where((event) => event is String)
        .cast<String>();
  }

  Future<void> start(List<String> paths) async {
    // Always invoke: the native side also starts the MediaStore observer, which
    // must run even when there are no custom FileObserver paths.
    await _method.invokeMethod<void>('start', {'paths': paths});
  }

  Future<void> stop() async {
    await _method.invokeMethod<void>('stop');
  }
}
