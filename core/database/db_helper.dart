import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import 'db_migration.dart';

/// Database Helper menggunakan Singleton Pattern
/// Mengelola koneksi dan operasi database SQLite
class DBHelper {
  DBHelper._internal();
  static final DBHelper instance = DBHelper._internal();

  static Database? _database;
  static const String _dbName = 'ledger_keuangan.db';
  static const int _dbVersion = 1;

  /// Getter untuk database instance
  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  /// Inisialisasi database
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onDowngrade: onDatabaseDowngradeDelete,
      onOpen: _onOpen,
    );
  }

  /// Callback saat database dibuat pertama kali
  Future<void> _onCreate(Database db, int version) async {
    await DBMigration.createTables(db);
    await DBMigration.insertDefaultData(db);
  }

  /// Callback saat database di-upgrade
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await DBMigration.migrate(db, oldVersion, newVersion);
  }

  /// Callback saat database dibuka
  Future<void> _onOpen(Database db) async {
    // Enable foreign keys
    await db.execute('PRAGMA foreign_keys = ON');
  }

  // ===== GENERIC CRUD OPERATIONS =====

  /// Insert data ke tabel
  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(
      table,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Insert data dengan transaction (atomic)
  Future<int> insertWithTransaction(
    String table,
    Map<String, dynamic> data,
    Future<void> Function(Transaction txn, int insertedId) additionalOperations,
  ) async {
    final db = await database;
    late int insertedId;

    await db.transaction((txn) async {
      insertedId = await txn.insert(
        table,
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await additionalOperations(txn, insertedId);
    });

    return insertedId;
  }

  /// Query semua data dari tabel
  Future<List<Map<String, dynamic>>> queryAll(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    return await db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  /// Query dengan kondisi
  Future<List<Map<String, dynamic>>> queryWhere(
    String table, {
    required String where,
    required List<dynamic> whereArgs,
    String? orderBy,
  }) async {
    final db = await database;
    return await db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
    );
  }

  /// Query single row by ID
  Future<Map<String, dynamic>?> queryById(String table, int id) async {
    final db = await database;
    final results = await db.query(
      table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Update data
  Future<int> update(
    String table,
    Map<String, dynamic> data, {
    required String where,
    required List<dynamic> whereArgs,
  }) async {
    final db = await database;
    return await db.update(
      table,
      data,
      where: where,
      whereArgs: whereArgs,
    );
  }

  /// Update by ID
  Future<int> updateById(
    String table,
    int id,
    Map<String, dynamic> data,
  ) async {
    final db = await database;
    return await db.update(
      table,
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Soft delete (set is_active = 0)
  Future<int> softDelete(String table, int id) async {
    final db = await database;
    return await db.update(
      table,
      {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Hard delete (permanent)
  Future<int> delete(
    String table, {
    required String where,
    required List<dynamic> whereArgs,
  }) async {
    final db = await database;
    return await db.delete(
      table,
      where: where,
      whereArgs: whereArgs,
    );
  }

  /// Delete by ID
  Future<int> deleteById(String table, int id) async {
    final db = await database;
    return await db.delete(
      table,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ===== TRANSACTION OPERATIONS =====

  /// Execute multiple operations in a transaction
  Future<T> executeTransaction<T>(
    Future<T> Function(Transaction txn) action,
  ) async {
    final db = await database;
    return await db.transaction(action);
  }

  /// Batch insert
  Future<List<int>> batchInsert(
    String table,
    List<Map<String, dynamic>> dataList,
  ) async {
    final db = await database;
    final batch = db.batch();

    for (final data in dataList) {
      batch.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    final results = await batch.commit();
    return results.cast<int>();
  }

  // ===== RAW QUERY =====

  /// Execute raw SQL query
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<dynamic>? arguments,
  ]) async {
    final db = await database;
    return await db.rawQuery(sql, arguments);
  }

  /// Execute raw SQL (INSERT, UPDATE, DELETE)
  Future<int> rawExecute(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawInsert(sql, arguments);
  }

  // ===== AGGREGATE FUNCTIONS =====

  /// Count rows in table
  Future<int> count(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $table ${where != null ? 'WHERE $where' : ''}',
      whereArgs,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Sum column in table
  Future<double> sum(
    String table,
    String column, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM($column) as total FROM $table ${where != null ? 'WHERE $where' : ''}',
      whereArgs,
    );
    final value = result.first['total'];
    if (value == null) return 0.0;
    return (value as num).toDouble();
  }

  // ===== UTILITY METHODS =====

  /// Check if table exists
  Future<bool> tableExists(String tableName) async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tableName],
    );
    return result.isNotEmpty;
  }

  /// Get table info
  Future<List<Map<String, dynamic>>> getTableInfo(String tableName) async {
    final db = await database;
    return await db.rawQuery('PRAGMA table_info($tableName)');
  }

  /// Close database connection
  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }

  /// Delete database file (untuk reset/testing)
  Future<void> deleteDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }

  /// Vacuum database (optimize storage)
  Future<void> vacuum() async {
    final db = await database;
    await db.execute('VACUUM');
  }
}
