import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../core/database/db_helper.dart';
import '../models/journal_entry.dart';
import '../models/transaction_model.dart';

class LedgerProvider with ChangeNotifier {
  // ============================================================
  // STATE UNTUK DAILY SUMMARY
  // ============================================================

  bool _isLoading = false;
  int _dailyIncome = 0;
  int _dailyExpense = 0;

  bool get isLoading => _isLoading;
  int get dailyIncome => _dailyIncome;
  int get dailyExpense => _dailyExpense;
  int get dailyProfit => _dailyIncome - _dailyExpense;

  // ============================================================
  // LOAD DAILY SUMMARY (REACTIVE)
  // ============================================================

  Future<void> loadDailySummary(DateTime date) async {
    _isLoading = true;
    notifyListeners();

    try {
      final summary = await getDailySummary(date);
      _dailyIncome = summary['income'] ?? 0;
      _dailyExpense = summary['expense'] ?? 0;
    } catch (e) {
      _dailyIncome = 0;
      _dailyExpense = 0;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refreshTodaySummary() async {
    await loadDailySummary(DateTime.now());
  }

  // ============================================================
  // HELPER METHODS
  // ============================================================

  Future<int> _getBalanceInTxn(
    Transaction txn,
    String accountId,
  ) async {
    final result = await txn.rawQuery(
      '''
      SELECT COALESCE(SUM(debit - credit), 0) AS balance
      FROM journal_entries
      WHERE account_id = ?
      ''',
      [accountId],
    );

    return (result.first['balance'] as int?) ?? 0;
  }

  Future<int> _getCurrentBalance(
    String accountId,
    Transaction txn,
  ) async {
    final result = await txn.rawQuery(
      '''
      SELECT COALESCE(SUM(debit - credit), 0) AS balance
      FROM journal_entries
      WHERE account_id = ?
      ''',
      [accountId],
    );

    final value = result.first['balance'];
    return (value is int) ? value : (value as num).toInt();
  }

  // ============================================================
  // TRANSACTION METHODS
  // ============================================================

  Future<void> adjustBalance({
    required String accountId,
    required int amountDiff,
    required String note,
  }) async {
    if (amountDiff == 0) return;

    final trxId = const Uuid().v4();

    final trx = TransactionModel(
      id: trxId,
      date: DateTime.now().millisecondsSinceEpoch,
      description: note,
      category: 'balance_adjustment',
    );

    final entries = <JournalEntry>[];

    if (amountDiff > 0) {
      entries.add(
        JournalEntry(
          id: const Uuid().v4(),
          transactionId: trxId,
          accountId: accountId,
          debit: amountDiff,
          credit: 0,
        ),
      );
      entries.add(
        JournalEntry(
          id: const Uuid().v4(),
          transactionId: trxId,
          accountId: 'MODAL',
          debit: 0,
          credit: amountDiff,
        ),
      );
    } else {
      final abs = amountDiff.abs();
      entries.add(
        JournalEntry(
          id: const Uuid().v4(),
          transactionId: trxId,
          accountId: accountId,
          debit: 0,
          credit: abs,
        ),
      );
      entries.add(
        JournalEntry(
          id: const Uuid().v4(),
          transactionId: trxId,
          accountId: 'PRIVE',
          debit: abs,
          credit: 0,
        ),
      );
    }

    await runTransaction(
      transaction: trx,
      entries: entries,
    );
  }

  Future<void> transferWithAdmin({
    required String fromAccountId,
    required String toAccountId,
    required int transferAmount,
    int adminFee = 0,
    String? note,
  }) async {
    if (fromAccountId == toAccountId) {
      throw Exception('Akun sumber dan tujuan tidak boleh sama');
    }

    if (transferAmount <= 0) {
      throw Exception('Nominal transfer tidak valid');
    }

    if (adminFee < 0 || adminFee > transferAmount) {
      throw Exception('Biaya admin tidak valid');
    }

    final receivedAmount = transferAmount - adminFee;

    final trxId = const Uuid().v4();

    final trx = TransactionModel(
      id: trxId,
      date: DateTime.now().millisecondsSinceEpoch,
      description: note ?? 'Transfer antar akun',
      category: 'transfer',
    );

    final entries = <JournalEntry>[
      JournalEntry(
        id: const Uuid().v4(),
        transactionId: trxId,
        accountId: toAccountId,
        debit: receivedAmount,
        credit: 0,
      ),
      if (adminFee > 0)
        JournalEntry(
          id: const Uuid().v4(),
          transactionId: trxId,
          accountId: 'BEBAN',
          debit: adminFee,
          credit: 0,
        ),
      JournalEntry(
        id: const Uuid().v4(),
        transactionId: trxId,
        accountId: fromAccountId,
        debit: 0,
        credit: transferAmount,
      ),
    ];

    await runTransaction(
      transaction: trx,
      entries: entries,
    );
  }

  Future<void> runTransaction({
    required TransactionModel transaction,
    required List<JournalEntry> entries,
    BuildContext? context,
  }) async {
    final db = await DBHelper.database;

    await db.transaction((txn) async {
      for (final entry in entries) {
        if (entry.credit > 0) {
          if (entry.accountId == 'MODAL' ||
              entry.accountId == 'PRIVE' ||
              entry.accountId == 'PENDAPATAN' ||
              entry.accountId == 'BEBAN') {
            continue;
          }

          final currentBalance =
              await _getCurrentBalance(entry.accountId, txn);

          if (currentBalance - entry.credit < 0) {
            throw Exception(
              'Saldo ${entry.accountId} tidak mencukupi',
            );
          }
        }
      }

      await txn.insert(
        'transactions',
        transaction.toMap(),
      );

      for (final entry in entries) {
        final before = await _getBalanceInTxn(txn, entry.accountId);
        final after = before + entry.debit - entry.credit;

        await txn.insert(
          'journal_entries',
          {
            ...entry.toMap(),
            'balance_before': before,
            'balance_after': after,
          },
        );
      }
    });

    await refreshTodaySummary();

    notifyListeners();
  }

  // ============================================================
  // QUERY METHODS
  // ============================================================

  Future<Map<String, int>> getDailySummary(DateTime date) async {
    final db = await DBHelper.database;

    final start = DateTime(date.year, date.month, date.day)
        .millisecondsSinceEpoch;
    final end = start + const Duration(days: 1).inMilliseconds;

    final result = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(CASE WHEN a.type = 'income' THEN j.credit ELSE 0 END), 0) AS income,
        COALESCE(SUM(CASE WHEN a.type = 'expense' THEN j.debit ELSE 0 END), 0) AS expense
      FROM journal_entries j
      JOIN accounts a ON a.id = j.account_id
      JOIN transactions t ON t.id = j.transaction_id
      WHERE t.date >= ? AND t.date < ?
    ''', [start, end]);

    final row = result.first;

    return {
      'income': (row['income'] as num).toInt(),
      'expense': (row['expense'] as num).toInt(),
    };
  }
}