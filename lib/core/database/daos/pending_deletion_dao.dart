import 'package:fileflow/core/database/database_helper.dart';
import 'package:fileflow/core/models/tracked_file.dart';
import 'package:sqflite/sqflite.dart';

class PendingDeletionDao {
  const PendingDeletionDao(this._db);
  final DatabaseHelper _db;

  Future<void> add(int fileId) async {
    final db = await _db.database;
    await db.insert(
      'pending_deletions',
      {
        'file_id': fileId,
        'queued_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> remove(int fileId) async {
    final db = await _db.database;
    await db.delete(
      'pending_deletions',
      where: 'file_id = ?',
      whereArgs: [fileId],
    );
  }

  Future<void> clearAll() async {
    final db = await _db.database;
    await db.delete('pending_deletions');
  }

  Future<Set<int>> getAllFileIds() async {
    final db = await _db.database;
    final rows = await db.query('pending_deletions', columns: ['file_id']);
    return rows.map((r) => r['file_id'] as int).toSet();
  }

  Future<List<TrackedFile>> getAllWithFiles() async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT tf.*
      FROM pending_deletions pd
      JOIN tracked_files tf ON tf.id = pd.file_id
      ORDER BY pd.queued_at ASC
    ''');
    return rows.map(TrackedFile.fromMap).toList();
  }

  Future<int> count() async {
    final db = await _db.database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as c FROM pending_deletions');
    return (result.first['c'] as int?) ?? 0;
  }
}
