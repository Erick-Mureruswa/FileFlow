import 'package:fileflow/core/database/database_helper.dart';
import 'package:fileflow/core/models/tracked_file.dart';
import 'package:sqflite/sqflite.dart';

class TrackedFileDao {
  const TrackedFileDao(this._helper);
  final DatabaseHelper _helper;

  static const _table = 'tracked_files';

  Future<List<TrackedFile>> getAll({bool includeDeleted = false}) async {
    final db = await _helper.database;
    final rows = await db.query(
      _table,
      where: includeDeleted ? null : 'is_deleted = 0',
      orderBy: 'detected_at DESC',
    );
    return rows.map(TrackedFile.fromMap).toList();
  }

  Future<List<TrackedFile>> getStarred() async {
    final db = await _helper.database;
    final rows = await db.query(
      _table,
      where: 'is_starred = 1 AND is_deleted = 0',
      orderBy: 'detected_at DESC',
    );
    return rows.map(TrackedFile.fromMap).toList();
  }

  Future<List<TrackedFile>> getExpiringSoon({int withinDays = 7}) async {
    final db = await _helper.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final cutoff = DateTime.now()
        .add(Duration(days: withinDays))
        .millisecondsSinceEpoch;
    final rows = await db.query(
      _table,
      where:
          'expires_at IS NOT NULL AND expires_at > ? AND expires_at <= ? AND is_deleted = 0 AND is_starred = 0',
      whereArgs: [now, cutoff],
      orderBy: 'expires_at ASC',
    );
    return rows.map(TrackedFile.fromMap).toList();
  }

  Future<List<TrackedFile>> getExpired() async {
    final db = await _helper.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query(
      _table,
      where:
          'expires_at IS NOT NULL AND expires_at <= ? AND is_deleted = 0 AND is_starred = 0',
      whereArgs: [now],
    );
    return rows.map(TrackedFile.fromMap).toList();
  }

  Future<List<TrackedFile>> getByFolder(int folderId) async {
    final db = await _helper.database;
    final rows = await db.query(
      _table,
      where: 'folder_id = ? AND is_deleted = 0',
      whereArgs: [folderId],
      orderBy: 'detected_at DESC',
    );
    return rows.map(TrackedFile.fromMap).toList();
  }

  Future<TrackedFile?> getByPath(String path) async {
    final db = await _helper.database;
    final rows = await db.query(_table, where: 'path = ?', whereArgs: [path]);
    if (rows.isEmpty) return null;
    return TrackedFile.fromMap(rows.first);
  }

  Future<int> insert(TrackedFile file) async {
    final db = await _helper.database;
    final map = file.toMap()..remove('id');
    return db.insert(_table, map, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> update(TrackedFile file) async {
    final db = await _helper.database;
    await db.update(
      _table,
      file.toMap(),
      where: 'id = ?',
      whereArgs: [file.id],
    );
  }

  Future<void> markDeleted(int id) async {
    final db = await _helper.database;
    await db.update(
      _table,
      {'is_deleted': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> setStarred(int id, {required bool starred}) async {
    final db = await _helper.database;
    await db.update(
      _table,
      {'is_starred': starred ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> setExpiry(int id, DateTime? expiresAt) async {
    final db = await _helper.database;
    await db.update(
      _table,
      {'expires_at': expiresAt?.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> countActive() async {
    final db = await _helper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM $_table WHERE is_deleted = 0',
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  Future<int> sumSizeDeleted() async {
    final db = await _helper.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(size), 0) as total FROM $_table WHERE is_deleted = 1',
    );
    return (result.first['total'] as int?) ?? 0;
  }

  Future<int> countDeletedThisMonth() async {
    final db = await _helper.database;
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM deletion_log WHERE deleted_at >= ?',
      [startOfMonth],
    );
    return (result.first['cnt'] as int?) ?? 0;
  }
}
