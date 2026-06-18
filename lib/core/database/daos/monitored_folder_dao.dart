import 'package:fileflow/core/database/database_helper.dart';
import 'package:fileflow/core/models/monitored_folder.dart';
import 'package:sqflite/sqflite.dart';

class MonitoredFolderDao {
  const MonitoredFolderDao(this._helper);
  final DatabaseHelper _helper;

  static const _table = 'monitored_folders';

  Future<List<MonitoredFolder>> getAll() async {
    final db = await _helper.database;
    final rows = await db.query(_table, orderBy: 'display_name ASC');
    return rows.map(MonitoredFolder.fromMap).toList();
  }

  Future<List<MonitoredFolder>> getEnabled() async {
    final db = await _helper.database;
    final rows = await db.query(
      _table,
      where: 'is_enabled = 1',
      orderBy: 'display_name ASC',
    );
    return rows.map(MonitoredFolder.fromMap).toList();
  }

  Future<MonitoredFolder?> getByPath(String path) async {
    final db = await _helper.database;
    final rows = await db.query(_table, where: 'path = ?', whereArgs: [path]);
    if (rows.isEmpty) return null;
    return MonitoredFolder.fromMap(rows.first);
  }

  Future<int> insert(MonitoredFolder folder) async {
    final db = await _helper.database;
    final map = folder.toMap()..remove('id');
    return db.insert(_table, map, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> update(MonitoredFolder folder) async {
    final db = await _helper.database;
    await db.update(
      _table,
      folder.toMap(),
      where: 'id = ?',
      whereArgs: [folder.id],
    );
  }

  Future<void> delete(int id) async {
    final db = await _helper.database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setEnabled(int id, {required bool enabled}) async {
    final db = await _helper.database;
    await db.update(
      _table,
      {'is_enabled': enabled ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
