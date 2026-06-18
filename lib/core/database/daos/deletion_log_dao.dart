import 'package:fileflow/core/database/database_helper.dart';
import 'package:fileflow/core/models/deletion_log_entry.dart';
import 'package:sqflite/sqflite.dart';

class DeletionLogDao {
  const DeletionLogDao(this._helper);
  final DatabaseHelper _helper;

  static const _table = 'deletion_log';

  Future<List<DeletionLogEntry>> getAll({int limit = 100}) async {
    final db = await _helper.database;
    final rows = await db.query(
      _table,
      orderBy: 'deleted_at DESC',
      limit: limit,
    );
    return rows.map(DeletionLogEntry.fromMap).toList();
  }

  Future<int> insert(DeletionLogEntry entry) async {
    final db = await _helper.database;
    final map = entry.toMap()..remove('id');
    return db.insert(_table, map, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> totalSpaceReclaimed() async {
    final db = await _helper.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(size), 0) as total FROM $_table',
    );
    return (result.first['total'] as int?) ?? 0;
  }

  Future<int> countThisMonth() async {
    final db = await _helper.database;
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month).millisecondsSinceEpoch;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM $_table WHERE deleted_at >= ?',
      [startOfMonth],
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  Future<int> spaceReclaimedThisMonth() async {
    final db = await _helper.database;
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month).millisecondsSinceEpoch;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(size), 0) as total FROM $_table WHERE deleted_at >= ?',
      [startOfMonth],
    );
    return (result.first['total'] as int?) ?? 0;
  }

  Future<List<DeletionLogEntry>> getRecentEntries({required int days}) async {
    final db = await _helper.database;
    final since = DateTime.now()
        .subtract(Duration(days: days))
        .millisecondsSinceEpoch;
    final rows = await db.query(
      _table,
      where: 'deleted_at >= ?',
      whereArgs: [since],
      orderBy: 'deleted_at ASC',
    );
    return rows.map(DeletionLogEntry.fromMap).toList();
  }

  Future<void> clear() async {
    final db = await _helper.database;
    await db.delete(_table);
  }
}
