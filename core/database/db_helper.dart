import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static const _dbName = 'ledger.db';
  static const _dbVersion = 1;

  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute(_createAccountsTable);
    await db.execute(_createTransactionsTable);
    await db.execute(_createJournalEntriesTable);
  }

  // ================= TABLES =================

  static const _createAccountsTable = '''
  CREATE TABLE accounts (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    type TEXT NOT NULL,
    sub_type TEXT NOT NULL,
    is_active INTEGER NOT NULL
  )
  ''';

  static const _createTransactionsTable = '''
  CREATE TABLE transactions (
    id TEXT PRIMARY KEY,
    date INTEGER NOT NULL,
    description TEXT,
    category TEXT,
    is_reversed INTEGER NOT NULL DEFAULT 0
  )
  ''';

  static const _createJournalEntriesTable = '''
  CREATE TABLE journal_entries (
    id TEXT PRIMARY KEY,
    transaction_id TEXT NOT NULL,
    account_id TEXT NOT NULL,
    debit INTEGER NOT NULL,
    credit INTEGER NOT NULL,
    balance_before INTEGER,
    balance_after INTEGER,
    FOREIGN KEY (transaction_id) REFERENCES transactions(id),
    FOREIGN KEY (account_id) REFERENCES accounts(id)
  )
  ''';
}
