import 'dart:io';

import 'package:fileflow/core/database/daos/monitored_folder_dao.dart';
import 'package:fileflow/core/database/daos/tracked_file_dao.dart';
import 'package:fileflow/core/models/file_arrival.dart';
import 'package:fileflow/core/models/monitored_folder.dart';
import 'package:fileflow/core/models/tracked_file.dart';
import 'package:fileflow/core/services/rule_engine.dart';
import 'package:fileflow/shared/utils/file_utils.dart';

/// Turns a raw watcher path event into a tracked file + a [FileArrival] for the
/// popup. The file is always tracked with the folder's default retention on
/// arrival, so "Ignore" / auto-dismiss simply leaves the default rule in place;
/// "Star" later flips the protection flag.
class FileArrivalService {
  const FileArrivalService(this._folderDao, this._fileDao, this._ruleEngine);

  final MonitoredFolderDao _folderDao;
  final TrackedFileDao _fileDao;
  final RuleEngine _ruleEngine;

  // Extensions used for in-progress downloads/copies — ignore until complete.
  static const _partialExtensions = [
    '.tmp',
    '.part',
    '.crdownload',
    '.download',
    '.pending',
    '.opdownload',
  ];

  Future<FileArrival?> processArrival(String path) async {
    final name = path.split('/').last;
    if (name.isEmpty || name.startsWith('.')) return null;
    if (_isPartial(name)) return null;
    if (_isGeneratedThumbnail(name)) return null;

    final entity = File(path);
    if (!entity.existsSync()) return null;

    final stat = await entity.stat();
    if (stat.type != FileSystemEntityType.file) return null;

    // Already tracked → nothing to do (avoids duplicate popups).
    final existing = await _fileDao.getByPath(path);
    if (existing != null) return null;

    final folder = await _findFolder(path);
    if (folder == null || !folder.isEnabled) return null;

    final detectedAt = DateTime.now();
    final expiresAt = _ruleEngine.computeExpiry(
      folder.defaultRetentionDays,
      detectedAt,
    );
    final fileType = FileUtils.detectType(name);

    final tracked = TrackedFile(
      id: 0,
      path: path,
      name: name,
      size: stat.size,
      fileType: fileType,
      folderId: folder.id,
      detectedAt: detectedAt,
      expiresAt: expiresAt,
      isStarred: false,
      isDeleted: false,
    );

    final id = await _fileDao.insert(tracked);
    if (id <= 0) return null; // insert ignored (raced with another path)

    return FileArrival(
      fileId: id,
      name: name,
      folderName: folder.displayName,
      path: path,
      fileType: fileType,
    );
  }

  // Pick the most specific enabled monitored folder that contains the file.
  Future<MonitoredFolder?> _findFolder(String path) async {
    final folders = await _folderDao.getEnabled();
    MonitoredFolder? best;
    for (final folder in folders) {
      if (path.startsWith('${folder.path}/')) {
        if (best == null || folder.path.length > best.path.length) {
          best = folder;
        }
      }
    }
    return best;
  }

  bool _isPartial(String name) {
    final lower = name.toLowerCase();
    return _partialExtensions.any(lower.endsWith);
  }

  // Samsung One UI writes a transient "thumbnail_<screenshot>.jpg" into the
  // Screenshots folder for its preview toolbar. It is auto-generated and usually
  // deleted shortly after, so it must never be tracked or surfaced as an arrival.
  bool _isGeneratedThumbnail(String name) {
    return name.toLowerCase().startsWith('thumbnail_');
  }
}
