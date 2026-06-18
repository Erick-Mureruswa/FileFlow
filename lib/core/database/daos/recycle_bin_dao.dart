import 'package:fileflow/core/database/database_helper.dart';
import 'package:fileflow/core/models/recycle_bin_item.dart';
import 'package:sqflite/sqflite.dart';

class RecycleBinDao {
  const RecycleBinDao(this._helper);
  final DatabaseHelper _helper;

  static const _table = 'recycle_bin';

  Future<List<RecycleBinItem>> getAll() async {
    final db = await _helper.database;
    final rows = await db.query(_table, orderBy: 'deleted_at DESC');
    return rows.map(RecycleBinItem.fromMap).toList();
  }

  Future<int> insert(RecycleBinItem item) async {
    final db = await _helper.database;
    final map = item.toMap()..remove('id');
    return db.insert(_table, map, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> delete(int id) async {
    final db = await _helper.database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteExpired() async {
    final db = await _helper.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.delete(
      _table,
      where: 'permanent_delete_at <= ?',
      whereArgs: [now],
    );
  }

  Future<void> clearAll() async {
    final db = await _helper.database;
    await db.delete(_table);
  }
}
