import 'dart:io';

import 'package:fileflow/core/database/daos/deletion_log_dao.dart';
import 'package:fileflow/core/database/daos/recycle_bin_dao.dart';
import 'package:fileflow/core/database/daos/tracked_file_dao.dart';
import 'package:fileflow/core/database/daos/retention_rule_dao.dart';
import 'package:fileflow/core/models/deletion_log_entry.dart';
import 'package:fileflow/core/models/recycle_bin_item.dart';
import 'package:fileflow/core/models/tracked_file.dart';
import 'package:fileflow/core/services/rule_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeletionResult {
  const DeletionResult({
    required this.deletedCount,
    required this.bytesFreed,
    required this.errors,
  });

  final int deletedCount;
  final int bytesFreed;
  final List<String> errors;
}

class DeletionService {
  const DeletionService(
    this._fileDao,
    this._ruleDao,
    this._logDao,
    this._recycleBinDao,
    this._ruleEngine,
  );

  final TrackedFileDao _fileDao;
  final RetentionRuleDao _ruleDao;
  final DeletionLogDao _logDao;
  final RecycleBinDao _recycleBinDao;
  final RuleEngine _ruleEngine;

  static const _prefRecycleBinEnabled = 'recycle_bin_enabled';
  static const _prefRecycleBinDays = 'recycle_bin_days';

  Future<DeletionResult> deleteExpired() async {
    final expiredFiles = await _fileDao.getExpired();
    final rules = await _ruleDao.getEnabled();
    final prefs = await SharedPreferences.getInstance();
    final recycleBinEnabled = prefs.getBool(_prefRecycleBinEnabled) ?? true;
    final recycleBinDays = prefs.getInt(_prefRecycleBinDays) ?? 7;

    int deletedCount = 0;
    int bytesFreed = 0;
    final errors = <String>[];

    for (final file in expiredFiles) {
      // Never delete starred files
      if (file.isStarred) continue;

      // Check protection rules
      if (_ruleEngine.isProtected(file, rules)) continue;

      try {
        await _deleteFile(
          file,
          recycleBinEnabled: recycleBinEnabled,
          recycleBinDays: recycleBinDays,
        );
        deletedCount++;
        bytesFreed += file.size;
      } on Exception catch (e) {
        errors.add('${file.name}: $e');
      }
    }

    // Also purge recycle bin items past their permanent-delete date
    await _recycleBinDao.deleteExpired();

    return DeletionResult(
      deletedCount: deletedCount,
      bytesFreed: bytesFreed,
      errors: errors,
    );
  }

  Future<void> deleteFileNow(TrackedFile file) async {
    final prefs = await SharedPreferences.getInstance();
    final recycleBinEnabled = prefs.getBool(_prefRecycleBinEnabled) ?? true;
    final recycleBinDays = prefs.getInt(_prefRecycleBinDays) ?? 7;

    await _deleteFile(
      file,
      recycleBinEnabled: recycleBinEnabled,
      recycleBinDays: recycleBinDays,
    );
  }

  Future<void> _deleteFile(
    TrackedFile file, {
    required bool recycleBinEnabled,
    required int recycleBinDays,
  }) async {
    final ioFile = File(file.path);
    if (ioFile.existsSync()) {
      await ioFile.delete();
    }

    await _fileDao.markDeleted(file.id);

    if (recycleBinEnabled) {
      final now = DateTime.now();
      await _recycleBinDao.insert(
        RecycleBinItem(
          id: 0,
          originalPath: file.path,
          name: file.name,
          size: file.size,
          fileType: file.fileType.name,
          deletedAt: now,
          permanentDeleteAt: now.add(Duration(days: recycleBinDays)),
        ),
      );
    }

    await _logDao.insert(
      DeletionLogEntry(
        id: 0,
        filePath: file.path,
        fileName: file.name,
        size: file.size,
        deletedAt: DateTime.now(),
        reason: 'auto',
      ),
    );
  }
}
