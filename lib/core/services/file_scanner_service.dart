import 'dart:io';

import 'package:fileflow/core/database/daos/monitored_folder_dao.dart';
import 'package:fileflow/core/database/daos/tracked_file_dao.dart';
import 'package:fileflow/core/models/monitored_folder.dart';
import 'package:fileflow/core/models/tracked_file.dart';
import 'package:fileflow/core/services/rule_engine.dart';
import 'package:fileflow/shared/utils/file_utils.dart';

class ScanResult {
  const ScanResult({
    required this.newFilesFound,
    required this.foldersScanned,
    required this.errors,
  });

  final int newFilesFound;
  final int foldersScanned;
  final List<String> errors;
}

class FileScannerService {
  const FileScannerService(this._folderDao, this._fileDao, this._ruleEngine);

  final MonitoredFolderDao _folderDao;
  final TrackedFileDao _fileDao;
  final RuleEngine _ruleEngine;

  Future<ScanResult> scanAll() async {
    final folders = await _folderDao.getEnabled();
    int newFiles = 0;
    final errors = <String>[];

    for (final folder in folders) {
      try {
        newFiles += await _scanFolder(folder);
      } on Exception catch (e) {
        errors.add('${folder.displayName}: $e');
      }
    }

    return ScanResult(
      newFilesFound: newFiles,
      foldersScanned: folders.length,
      errors: errors,
    );
  }

  Future<int> _scanFolder(MonitoredFolder folder) async {
    final dir = Directory(folder.path);
    if (!dir.existsSync()) return 0;

    int count = 0;

    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final path = entity.path;

      // Skip if already tracked
      final existing = await _fileDao.getByPath(path);
      if (existing != null) continue;

      try {
        final stat = await entity.stat();
        final name = path.split(Platform.pathSeparator).last;
        final fileType = FileUtils.detectType(name);
        final detectedAt = DateTime.now();
        final expiresAt = _ruleEngine.computeExpiry(
          folder.defaultRetentionDays,
          detectedAt,
        );

        final newFile = TrackedFile(
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

        await _fileDao.insert(newFile);
        count++;
      } on FileSystemException {
        // Skip files we can't stat (e.g., permission denied on individual files)
        continue;
      }
    }

    return count;
  }

  // Reconcile: remove DB entries for files that no longer exist on disk.
  Future<int> reconcile() async {
    final files = await _fileDao.getAll();
    int removed = 0;

    for (final file in files) {
      if (!await _ruleEngine.fileExists(file.path)) {
        await _fileDao.markDeleted(file.id);
        removed++;
      }
    }

    return removed;
  }
}
