import 'package:fileflow/core/database/database_helper.dart';
import 'package:fileflow/core/models/retention_rule.dart';
import 'package:sqflite/sqflite.dart';

class RetentionRuleDao {
  const RetentionRuleDao(this._helper);
  final DatabaseHelper _helper;

  static const _table = 'retention_rules';

  Future<List<RetentionRule>> getAll() async {
    final db = await _helper.database;
    final rows = await db.query(_table, orderBy: 'priority DESC, created_at ASC');
    return rows.map(RetentionRule.fromMap).toList();
  }

  Future<List<RetentionRule>> getEnabled() async {
    final db = await _helper.database;
    final rows = await db.query(
      _table,
      where: 'is_enabled = 1',
      orderBy: 'priority DESC',
    );
    return rows.map(RetentionRule.fromMap).toList();
  }

  Future<int> insert(RetentionRule rule) async {
    final db = await _helper.database;
    final map = rule.toMap()..remove('id');
    return db.insert(_table, map, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> update(RetentionRule rule) async {
    final db = await _helper.database;
    await db.update(
      _table,
      rule.toMap(),
      where: 'id = ?',
      whereArgs: [rule.id],
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
