import 'package:path/path.dart' as path_pkg;
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'fileflow.db';
  static const _dbVersion = 2;

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final fullPath = path_pkg.join(dbPath, _dbName);
    return openDatabase(
      fullPath,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) => db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE monitored_folders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        path TEXT NOT NULL UNIQUE,
        display_name TEXT NOT NULL,
        is_enabled INTEGER NOT NULL DEFAULT 1,
        default_retention_days INTEGER NOT NULL DEFAULT 30,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE tracked_files (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        path TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        size INTEGER NOT NULL,
        file_type TEXT NOT NULL,
        folder_id INTEGER NOT NULL,
        detected_at INTEGER NOT NULL,
        expires_at INTEGER,
        is_starred INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (folder_id) REFERENCES monitored_folders(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE retention_rules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        rule_type TEXT NOT NULL,
        condition_value TEXT,
        priority INTEGER NOT NULL DEFAULT 0,
        is_enabled INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE recycle_bin (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        original_path TEXT NOT NULL,
        name TEXT NOT NULL,
        size INTEGER NOT NULL,
        file_type TEXT NOT NULL,
        deleted_at INTEGER NOT NULL,
        permanent_delete_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE deletion_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        file_path TEXT NOT NULL,
        file_name TEXT NOT NULL,
        size INTEGER NOT NULL,
        deleted_at INTEGER NOT NULL,
        reason TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE pending_deletions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        file_id INTEGER NOT NULL UNIQUE,
        queued_at INTEGER NOT NULL,
        FOREIGN KEY (file_id) REFERENCES tracked_files(id) ON DELETE CASCADE
      )
    ''');

    // Indexes for common queries
    await db.execute(
      'CREATE INDEX idx_tracked_files_folder ON tracked_files(folder_id)',
    );
    await db.execute(
      'CREATE INDEX idx_tracked_files_expires ON tracked_files(expires_at)',
    );
    await db.execute(
      'CREATE INDEX idx_tracked_files_starred ON tracked_files(is_starred)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS pending_deletions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          file_id INTEGER NOT NULL UNIQUE,
          queued_at INTEGER NOT NULL,
          FOREIGN KEY (file_id) REFERENCES tracked_files(id) ON DELETE CASCADE
        )
      ''');
    }
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
