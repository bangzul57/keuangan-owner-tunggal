import 'package:flutter/material.dart';
import '../core/database/db_helper.dart';

class TransactionProvider with ChangeNotifier {
  List<Map<String, dynamic>> _transactions = [];

  List<Map<String, dynamic>> get transactions => _transactions;

  Future<void> loadTransactions() async {
    final db = await DBHelper.database;

    final result = await db.rawQuery('''
      SELECT 
        id,
        date,
        description,
        category
      FROM transactions
      WHERE is_reversed = 0
      ORDER BY date DESC
    ''');

    _transactions = result;
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> loadJournalByTransaction(
    String transactionId,
  ) async {
    final db = await DBHelper.database;

    return await db.rawQuery('''
      SELECT 
        j.account_id,
        a.name AS account_name,
        j.debit,
        j.credit
      FROM journal_entries j
      JOIN accounts a ON a.id = j.account_id
      WHERE j.transaction_id = ?
    ''', [transactionId]);
  }
}