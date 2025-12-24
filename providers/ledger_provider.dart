import 'package:flutter/foundation.dart';

import '../core/database/db_helper.dart';
import '../core/database/db_migration.dart';
import '../models/journal_entry.dart';

/// Provider untuk mengelola Journal Entries (Buku Besar)
class LedgerProvider extends ChangeNotifier {
  final DBHelper _dbHelper = DBHelper.instance;

  List<JournalEntry> _entries = [];
  List<JournalEntry> _filteredEntries = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Filter state
  int? _filterAccountId;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  EntryType? _filterEntryType;

  // ===== GETTERS =====

  List<JournalEntry> get entries => List.unmodifiable(_entries);

  List<JournalEntry> get filteredEntries => List.unmodifiable(_filteredEntries);

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  int? get filterAccountId => _filterAccountId;

  DateTime? get filterStartDate => _filterStartDate;

  DateTime? get filterEndDate => _filterEndDate;

  EntryType? get filterEntryType => _filterEntryType;

  bool get hasActiveFilter =>
      _filterAccountId != null ||
      _filterStartDate != null ||
      _filterEndDate != null ||
      _filterEntryType != null;

  /// Total debit dari semua entries
  double get totalDebit => _entries.totalDebit;

  /// Total credit dari semua entries
  double get totalCredit => _entries.totalCredit;

  /// Cek apakah balance (debit = credit)
  bool get isBalanced => _entries.isBalanced;

  /// Total debit dari filtered entries
  double get filteredTotalDebit => _filteredEntries.totalDebit;

  /// Total credit dari filtered entries
  double get filteredTotalCredit => _filteredEntries.totalCredit;

  // ===== LOAD OPERATIONS =====

  /// Load semua journal entries dari database
  Future<void> loadEntries() async {
    _setLoading(true);
    _clearError();

    try {
      // Query dengan join untuk mendapatkan nama akun
      final maps = await _dbHelper.rawQuery('''
        SELECT 
          je.*,
          a.name as account_name,
          a.type as account_type,
          t.transaction_code
        FROM ${DBMigration.tableJournalEntries} je
        LEFT JOIN ${DBMigration.tableAccounts} a ON je.account_id = a.id
        LEFT JOIN ${DBMigration.tableTransactions} t ON je.transaction_id = t.id
        ORDER BY je.created_at DESC
      ''');

      _entries = maps.map((map) => JournalEntry.fromMap(map)).toList();
      _applyFilters();
      notifyListeners();
    } catch (e) {
      _setError('Gagal memuat data jurnal: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Load entries untuk akun tertentu
  Future<List<JournalEntry>> loadEntriesForAccount(int accountId) async {
    try {
      final maps = await _dbHelper.rawQuery('''
        SELECT 
          je.*,
          a.name as account_name,
          a.type as account_type,
          t.transaction_code
        FROM ${DBMigration.tableJournalEntries} je
        LEFT JOIN ${DBMigration.tableAccounts} a ON je.account_id = a.id
        LEFT JOIN ${DBMigration.tableTransactions} t ON je.transaction_id = t.id
        WHERE je.account_id = ?
        ORDER BY je.created_at DESC
      ''', [accountId]);

      return maps.map((map) => JournalEntry.fromMap(map)).toList();
    } catch (e) {
      _setError('Gagal memuat data jurnal akun: $e');
      return [];
    }
  }

  /// Load entries untuk transaksi tertentu
  Future<List<JournalEntry>> loadEntriesForTransaction(int transactionId) async {
    try {
      final maps = await _dbHelper.rawQuery('''
        SELECT 
          je.*,
          a.name as account_name,
          a.type as account_type,
          t.transaction_code
        FROM ${DBMigration.tableJournalEntries} je
        LEFT JOIN ${DBMigration.tableAccounts} a ON je.account_id = a.id
        LEFT JOIN ${DBMigration.tableTransactions} t ON je.transaction_id = t.id
        WHERE je.transaction_id = ?
        ORDER BY je.id ASC
      ''', [transactionId]);

      return maps.map((map) => JournalEntry.fromMap(map)).toList();
    } catch (e) {
      _setError('Gagal memuat data jurnal transaksi: $e');
      return [];
    }
  }

  // ===== CREATE OPERATIONS =====

  /// Tambah journal entry baru
  Future<int?> addEntry(JournalEntry entry) async {
    _clearError();

    try {
      final id = await _dbHelper.insert(
        DBMigration.tableJournalEntries,
        entry.toMap(),
      );

      final newEntry = entry.copyWith(id: id);
      _entries.insert(0, newEntry);
      _applyFilters();
      notifyListeners();

      return id;
    } catch (e) {
      _setError('Gagal menambah jurnal: $e');
      return null;
    }
  }

  /// Tambah multiple journal entries (untuk double-entry)
  Future<bool> addEntries(List<JournalEntry> entries) async {
    _clearError();

    try {
      // Validasi double-entry: total debit harus sama dengan total credit
      final totalDebit = entries.totalDebit;
      final totalCredit = entries.totalCredit;

      if ((totalDebit - totalCredit).abs() > 0.01) {
        _setError(
          'Double-entry tidak balance: Debit=$totalDebit, Credit=$totalCredit',
        );
        return false;
      }

      // Insert semua entries
      for (final entry in entries) {
        await _dbHelper.insert(
          DBMigration.tableJournalEntries,
          entry.toMap(),
        );
      }

      // Reload entries
      await loadEntries();

      return true;
    } catch (e) {
      _setError('Gagal menambah jurnal: $e');
      return false;
    }
  }

  // ===== FILTER OPERATIONS =====

  /// Set filter berdasarkan akun
  void setAccountFilter(int? accountId) {
    _filterAccountId = accountId;
    _applyFilters();
    notifyListeners();
  }

  /// Set filter berdasarkan rentang tanggal
  void setDateFilter(DateTime? startDate, DateTime? endDate) {
    _filterStartDate = startDate;
    _filterEndDate = endDate;
    _applyFilters();
    notifyListeners();
  }

  /// Set filter berdasarkan tipe entry
  void setEntryTypeFilter(EntryType? entryType) {
    _filterEntryType = entryType;
    _applyFilters();
    notifyListeners();
  }

  /// Clear semua filter
  void clearFilters() {
    _filterAccountId = null;
    _filterStartDate = null;
    _filterEndDate = null;
    _filterEntryType = null;
    _filteredEntries = List.from(_entries);
    notifyListeners();
  }

  /// Apply all active filters
  void _applyFilters() {
    _filteredEntries = _entries.where((entry) {
      // Filter by account
      if (_filterAccountId != null && entry.accountId != _filterAccountId) {
        return false;
      }

      // Filter by date range
      if (_filterStartDate != null) {
        final entryDate = DateTime(
          entry.createdAt.year,
          entry.createdAt.month,
          entry.createdAt.day,
        );
        final startDate = DateTime(
          _filterStartDate!.year,
          _filterStartDate!.month,
          _filterStartDate!.day,
        );
        if (entryDate.isBefore(startDate)) {
          return false;
        }
      }

      if (_filterEndDate != null) {
        final entryDate = DateTime(
          entry.createdAt.year,
          entry.createdAt.month,
          entry.createdAt.day,
        );
        final endDate = DateTime(
          _filterEndDate!.year,
          _filterEndDate!.month,
          _filterEndDate!.day,
        );
        if (entryDate.isAfter(endDate)) {
          return false;
        }
      }

      // Filter by entry type
      if (_filterEntryType != null && entry.entryType != _filterEntryType) {
        return false;
      }

      return true;
    }).toList();
  }

  // ===== SUMMARY & ANALYTICS =====

  /// Hitung saldo akun dari journal entries
  Future<double> calculateAccountBalance(int accountId) async {
    try {
      final entries = await loadEntriesForAccount(accountId);

      double balance = 0;
      for (final entry in entries) {
        if (entry.isDebit) {
          balance += entry.amount;
        } else {
          balance -= entry.amount;
        }
      }

      return balance;
    } catch (e) {
      _setError('Gagal menghitung saldo: $e');
      return 0;
    }
  }

  /// Dapatkan ringkasan per akun
  Map<int, Map<String, double>> getAccountSummary() {
    final summary = <int, Map<String, double>>{};

    for (final entry in _entries) {
      if (!summary.containsKey(entry.accountId)) {
        summary[entry.accountId] = {'debit': 0, 'credit': 0};
      }

      if (entry.isDebit) {
        summary[entry.accountId]!['debit'] =
            (summary[entry.accountId]!['debit'] ?? 0) + entry.amount;
      } else {
        summary[entry.accountId]!['credit'] =
            (summary[entry.accountId]!['credit'] ?? 0) + entry.amount;
      }
    }

    return summary;
  }

  /// Dapatkan ringkasan harian
  Map<DateTime, Map<String, double>> getDailySummary({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final summary = <DateTime, Map<String, double>>{};

    for (final entry in _entries) {
      final date = DateTime(
        entry.createdAt.year,
        entry.createdAt.month,
        entry.createdAt.day,
      );

      // Apply date filter
      if (startDate != null && date.isBefore(startDate)) continue;
      if (endDate != null && date.isAfter(endDate)) continue;

      if (!summary.containsKey(date)) {
        summary[date] = {'debit': 0, 'credit': 0};
      }

      if (entry.isDebit) {
        summary[date]!['debit'] = (summary[date]!['debit'] ?? 0) + entry.amount;
      } else {
        summary[date]!['credit'] =
            (summary[date]!['credit'] ?? 0) + entry.amount;
      }
    }

    return summary;
  }

  // ===== RECONCILIATION =====

  /// Rekonsiliasi: Hitung ulang saldo dari semua journal entries
  Future<Map<int, double>> reconcileAllAccounts() async {
    try {
      final balances = <int, double>{};

      // Query untuk menghitung balance per akun
      final results = await _dbHelper.rawQuery('''
        SELECT 
          account_id,
          SUM(CASE WHEN entry_type = 'debit' THEN amount ELSE 0 END) as total_debit,
          SUM(CASE WHEN entry_type = 'credit' THEN amount ELSE 0 END) as total_credit
        FROM ${DBMigration.tableJournalEntries}
        GROUP BY account_id
      ''');

      for (final row in results) {
        final accountId = row['account_id'] as int;
        final totalDebit = (row['total_debit'] as num?)?.toDouble() ?? 0;
        final totalCredit = (row['total_credit'] as num?)?.toDouble() ?? 0;
        balances[accountId] = totalDebit - totalCredit;
      }

      return balances;
    } catch (e) {
      _setError('Gagal melakukan rekonsiliasi: $e');
      return {};
    }
  }

  // ===== HELPER METHODS =====

  /// Get entry by ID
  JournalEntry? getEntryById(int id) {
    try {
      return _entries.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get entries by transaction ID
  List<JournalEntry> getEntriesByTransaction(int transactionId) {
    return _entries.where((e) => e.transactionId == transactionId).toList();
  }

  /// Refresh data dari database
  Future<void> refresh() async {
    await loadEntries();
  }

  // ===== PRIVATE METHODS =====

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  /// Clear error message
  void clearError() {
    _clearError();
    notifyListeners();
  }
}
