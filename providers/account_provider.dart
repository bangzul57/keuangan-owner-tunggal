import 'package:flutter/material.dart';

import '../core/database/db_helper.dart';
import '../models/account.dart';

class AccountProvider with ChangeNotifier {
  // ============================================================
  // STATE
  // ============================================================

  List<Map<String, dynamic>> _assetAccounts = [];

  List<Map<String, dynamic>> get assetAccounts => _assetAccounts;

  // ============================================================
  // CONSTANTS
  // ============================================================

  static const List<String> _protectedAccountIds = [
    'KAS',
    'PRIVE',
    'MODAL',
    'PENDAPATAN',
    'BEBAN',
  ];

  static final List<Account> _defaultAccounts = [
    Account(
      id: 'KAS',
      name: 'Kas',
      type: 'asset',
      subType: 'cash',
      isActive: true,
    ),
    Account(
      id: 'MODAL',
      name: 'Modal',
      type: 'equity',
      subType: 'capital',
      isActive: true,
    ),
    Account(
      id: 'PRIVE',
      name: 'Prive',
      type: 'equity',
      subType: 'prive',
      isActive: true,
    ),
    Account(
      id: 'PENDAPATAN',
      name: 'Pendapatan',
      type: 'income',
      subType: 'revenue',
      isActive: true,
    ),
    Account(
      id: 'BEBAN',
      name: 'Beban',
      type: 'expense',
      subType: 'expense',
      isActive: true,
    ),
  ];

  // ============================================================
  // LOAD METHODS
  // ============================================================

  Future<void> loadAssetAccounts() async {
    final db = await DBHelper.database;

    final result = await db.rawQuery('''
      SELECT 
        a.id,
        a.name,
        a.sub_type,
        COALESCE(SUM(j.debit - j.credit), 0) AS balance
      FROM accounts a
      LEFT JOIN journal_entries j ON j.account_id = a.id
      WHERE a.type = 'asset' AND a.is_active = 1
      GROUP BY a.id
      ORDER BY a.name ASC
    ''');

    _assetAccounts = result;
    notifyListeners();
  }

  // ============================================================
  // LOAD RECEIVABLE (HUTANG PELANGGAN)
  // ============================================================

  Future<List<Map<String, dynamic>>> loadReceivables() async {
    final db = await DBHelper.database;

    return await db.rawQuery('''
      SELECT 
        a.id,
        a.name,
        COALESCE(SUM(j.debit - j.credit), 0) AS balance
      FROM accounts a
      LEFT JOIN journal_entries j ON j.account_id = a.id
      WHERE a.sub_type = 'receivable'
        AND a.is_active = 1
      GROUP BY a.id
      HAVING balance != 0
      ORDER BY a.name ASC
    ''');
  }

  // ============================================================
  // SEED METHODS
  // ============================================================

  Future<void> seedDefaultAccounts() async {
    final db = await DBHelper.database;

    final result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM accounts',
    );
    final count = result.first['count'] as int;

    if (count > 0) return;

    for (final acc in _defaultAccounts) {
      await db.insert('accounts', acc.toMap());
    }
  }

  // ============================================================
  // CRUD METHODS
  // ============================================================

  Future<void> addAccount(Account account) async {
    final db = await DBHelper.database;
    await db.insert('accounts', account.toMap());
    await loadAssetAccounts();
  }

  Future<void> deactivateAccount(String accountId) async {
    if (_protectedAccountIds.contains(accountId)) {
      throw Exception('Akun sistem tidak boleh dihapus');
    }

    final db = await DBHelper.database;

    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(debit - credit), 0) AS balance
      FROM journal_entries
      WHERE account_id = ?
    ''', [accountId]);

    final balance = (result.first['balance'] as num).toInt();

    if (balance != 0) {
      throw Exception('Saldo akun harus 0 sebelum dihapus');
    }

    await db.update(
      'accounts',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [accountId],
    );

    await loadAssetAccounts();
  }
}