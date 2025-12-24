import 'package:flutter/foundation.dart';

import '../core/database/db_helper.dart';
import '../core/database/db_migration.dart';
import '../core/utils/formatters.dart';
import '../models/receivable.dart';
import '../models/transaction_model.dart';
import 'account_provider.dart';

/// Provider untuk mengelola Piutang (Receivable)
class ReceivableProvider extends ChangeNotifier {
  final DBHelper _dbHelper = DBHelper.instance;

  // Dependency
  AccountProvider? _accountProvider;

  List<Receivable> _receivables = [];
  List<ReceivablePayment> _payments = [];
  bool _isLoading = false;
  bool _isProcessing = false;
  String? _errorMessage;

  // ===== DEPENDENCY INJECTION =====

  void updateDependencies(AccountProvider accountProvider) {
    _accountProvider = accountProvider;
  }

  // ===== GETTERS =====

  List<Receivable> get receivables => List.unmodifiable(_receivables);

  List<Receivable> get activeReceivables =>
      _receivables.where((r) => r.isActive).toList();

  List<ReceivablePayment> get payments => List.unmodifiable(_payments);

  bool get isLoading => _isLoading;

  bool get isProcessing => _isProcessing;

  String? get errorMessage => _errorMessage;

  /// Piutang yang belum lunas
  List<Receivable> get unpaidReceivables => activeReceivables.unpaidOnly;

  /// Piutang yang sudah lunas
  List<Receivable> get paidReceivables => activeReceivables.paidOnly;

  /// Piutang yang jatuh tempo
  List<Receivable> get overdueReceivables => activeReceivables.overdueOnly;

  /// Total piutang belum lunas
  double get totalOutstanding => activeReceivables.totalOutstanding;

  /// Total yang sudah dibayar
  double get totalPaid => activeReceivables.totalPaid;

  /// Jumlah piutang jatuh tempo
  int get overdueCount => overdueReceivables.length;

  /// Jumlah piutang aktif
  int get activeCount => unpaidReceivables.length;

  // ===== LOAD OPERATIONS =====

  /// Load semua piutang dari database
  Future<void> loadReceivables() async {
    _setLoading(true);
    _clearError();

    try {
      final maps = await _dbHelper.queryAll(
        DBMigration.tableReceivables,
        where: 'is_active = ?',
        whereArgs: [1],
        orderBy: 'due_date ASC, created_at DESC',
      );

      _receivables = maps.map((map) => Receivable.fromMap(map)).toList();
      notifyListeners();
    } catch (e) {
      _setError('Gagal memuat data piutang: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Load piutang dengan payments
  Future<Receivable?> loadReceivableWithPayments(int receivableId) async {
    try {
      final receivableMap = await _dbHelper.queryById(
        DBMigration.tableReceivables,
        receivableId,
      );

      if (receivableMap == null) return null;

      final paymentMaps = await _dbHelper.rawQuery('''
        SELECT 
          rp.*,
          a.name as destination_account_name
        FROM ${DBMigration.tableReceivablePayments} rp
        LEFT JOIN ${DBMigration.tableAccounts} a ON rp.destination_account_id = a.id
        WHERE rp.receivable_id = ?
        ORDER BY rp.payment_date DESC
      ''', [receivableId]);

      final payments = paymentMaps
          .map((map) => ReceivablePayment.fromMap(map))
          .toList();

      return Receivable.fromMap(receivableMap).copyWith(payments: payments);
    } catch (e) {
      _setError('Gagal memuat detail piutang: $e');
      return null;
    }
  }

  /// Load payments untuk piutang tertentu
  Future<List<ReceivablePayment>> loadPayments(int receivableId) async {
    try {
      final maps = await _dbHelper.rawQuery('''
        SELECT 
          rp.*,
          a.name as destination_account_name
        FROM ${DBMigration.tableReceivablePayments} rp
        LEFT JOIN ${DBMigration.tableAccounts} a ON rp.destination_account_id = a.id
        WHERE rp.receivable_id = ?
        ORDER BY rp.payment_date DESC
      ''', [receivableId]);

      return maps.map((map) => ReceivablePayment.fromMap(map)).toList();
    } catch (e) {
      _setError('Gagal memuat riwayat pembayaran: $e');
      return [];
    }
  }

  // ===== CREATE OPERATIONS =====

  /// Tambah piutang baru (biasanya dipanggil dari TransactionProvider)
  Future<int?> addReceivable(Receivable receivable) async {
    _clearError();

    try {
      final id = await _dbHelper.insert(
        DBMigration.tableReceivables,
        receivable.toMap(),
      );

      final newReceivable = receivable.copyWith(id: id);
      _receivables.insert(0, newReceivable);
      _sortReceivables();
      notifyListeners();

      return id;
    } catch (e) {
      _setError('Gagal menambah piutang: $e');
      return null;
    }
  }

  // ===== PAYMENT OPERATIONS =====

  /// Terima pembayaran piutang
  Future<bool> receivePayment({
    required int receivableId,
    required double amount,
    required PaymentMethod paymentMethod,
    required int destinationAccountId,
    String? notes,
    DateTime? paymentDate,
  }) async {
    if (_isProcessing) return false;
    _setProcessing(true);
    _clearError();

    try {
      final receivable = getReceivableById(receivableId);
      if (receivable == null) {
        _setError('Piutang tidak ditemukan');
        return false;
      }

      if (receivable.isPaid) {
        _setError('Piutang sudah lunas');
        return false;
      }

      if (amount <= 0) {
        _setError('Nominal pembayaran harus lebih dari 0');
        return false;
      }

      if (amount > receivable.remainingAmount) {
        _setError(
          'Nominal melebihi sisa hutang (Rp ${Formatters.formatNumber(receivable.remainingAmount)})',
        );
        return false;
      }

      final destAccount = _accountProvider?.getAccountById(destinationAccountId);
      if (destAccount == null) {
        _setError('Akun tujuan tidak ditemukan');
        return false;
      }

      await _dbHelper.executeTransaction((txn) async {
        final now = paymentDate ?? DateTime.now();
        final transactionCode = Formatters.generateTransactionCode('PAY');

        // Hitung saldo baru
        final newPaidAmount = receivable.paidAmount + amount;
        final newRemainingAmount = receivable.remainingAmount - amount;
        final newStatus = newRemainingAmount <= 0
            ? ReceivableStatus.paid
            : ReceivableStatus.partial;

        // Update receivable
        await txn.update(
          DBMigration.tableReceivables,
          {
            'paid_amount': newPaidAmount,
            'remaining_amount': newRemainingAmount,
            'status': newStatus.value,
            'updated_at': now.toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [receivableId],
        );

        // Insert payment record
        await txn.insert(
          DBMigration.tableReceivablePayments,
          {
            'receivable_id': receivableId,
            'amount': amount,
            'payment_method': paymentMethod.value,
            'destination_account_id': destinationAccountId,
            'notes': notes,
            'payment_date': now.toIso8601String(),
            'created_at': now.toIso8601String(),
          },
        );

        // Update saldo akun tujuan
        final destBalanceBefore = destAccount.balance;
        await txn.update(
          DBMigration.tableAccounts,
          {
            'balance': destBalanceBefore + amount,
            'updated_at': now.toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [destinationAccountId],
        );

        // Insert transaction record
        final transactionId = await txn.insert(
          DBMigration.tableTransactions,
          {
            'transaction_code': transactionCode,
            'transaction_type': TransactionType.receivablePayment.value,
            'amount': amount,
            'profit': 0, // Profit sudah dicatat saat piutang dibuat
            'destination_account_id': destinationAccountId,
            'receivable_id': receivableId,
            'buyer_name': receivable.buyerName,
            'description': 'Pembayaran piutang dari ${receivable.buyerName}',
            'notes': notes,
            'balance_before_dest': destBalanceBefore,
            'balance_after_dest': destBalanceBefore + amount,
            'transaction_date': now.toIso8601String(),
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          },
        );

        // Insert journal entry
        await txn.insert(
          DBMigration.tableJournalEntries,
          {
            'transaction_id': transactionId,
            'account_id': destinationAccountId,
            'entry_type': 'debit',
            'amount': amount,
            'balance_before': destBalanceBefore,
            'balance_after': destBalanceBefore + amount,
            'description': 'Pembayaran piutang - ${receivable.buyerName}',
            'created_at': now.toIso8601String(),
          },
        );
      });

      // Reload data
      await _accountProvider?.loadAccounts();
      await loadReceivables();

      return true;
    } catch (e) {
      _setError('Gagal memproses pembayaran: $e');
      return false;
    } finally {
      _setProcessing(false);
    }
  }

  // ===== UPDATE OPERATIONS =====

  /// Update piutang
  Future<bool> updateReceivable(Receivable receivable) async {
    _clearError();

    if (receivable.id == null) {
      _setError('ID piutang tidak valid');
      return false;
    }

    try {
      final updatedReceivable = receivable.copyWith(
        updatedAt: DateTime.now(),
      );

      await _dbHelper.updateById(
        DBMigration.tableReceivables,
        receivable.id!,
        updatedReceivable.toMap(),
      );

      final index = _receivables.indexWhere((r) => r.id == receivable.id);
      if (index != -1) {
        _receivables[index] = updatedReceivable;
        _sortReceivables();
        notifyListeners();
      }

      return true;
    } catch (e) {
      _setError('Gagal mengupdate piutang: $e');
      return false;
    }
  }

  /// Update jatuh tempo
  Future<bool> updateDueDate(int receivableId, DateTime? dueDate) async {
    final receivable = getReceivableById(receivableId);
    if (receivable == null) {
      _setError('Piutang tidak ditemukan');
      return false;
    }

    return updateReceivable(receivable.copyWith(dueDate: dueDate));
  }

  // ===== DELETE OPERATIONS =====

  /// Soft delete piutang
  Future<bool> deleteReceivable(int receivableId) async {
    _clearError();

    try {
      final receivable = getReceivableById(receivableId);
      if (receivable == null) {
        _setError('Piutang tidak ditemukan');
        return false;
      }

      // Cek apakah ada pembayaran
      final payments = await loadPayments(receivableId);
      if (payments.isNotEmpty) {
        _setError('Tidak dapat menghapus piutang yang sudah ada pembayaran');
        return false;
      }

      await _dbHelper.softDelete(DBMigration.tableReceivables, receivableId);

      _receivables.removeWhere((r) => r.id == receivableId);
      notifyListeners();

      return true;
    } catch (e) {
      _setError('Gagal menghapus piutang: $e');
      return false;
    }
  }

  /// Batalkan piutang (mark as cancelled)
  Future<bool> cancelReceivable(int receivableId, String reason) async {
    _clearError();

    try {
      final receivable = getReceivableById(receivableId);
      if (receivable == null) {
        _setError('Piutang tidak ditemukan');
        return false;
      }

      final now = DateTime.now();

      await _dbHelper.updateById(
        DBMigration.tableReceivables,
        receivableId,
        {
          'status': ReceivableStatus.cancelled.value,
          'notes': '${receivable.notes ?? ''}\n[Dibatalkan: $reason]'.trim(),
          'updated_at': now.toIso8601String(),
        },
      );

      // Insert audit log
      await _dbHelper.insert(
        DBMigration.tableAuditLogs,
        {
          'table_name': DBMigration.tableReceivables,
          'record_id': receivableId,
          'action': 'cancel',
          'old_data': receivable.toString(),
          'user_note': reason,
          'created_at': now.toIso8601String(),
        },
      );

      await loadReceivables();

      return true;
    } catch (e) {
      _setError('Gagal membatalkan piutang: $e');
      return false;
    }
  }

  // ===== HELPER METHODS =====

  /// Get receivable by ID
  Receivable? getReceivableById(int id) {
    try {
      return _receivables.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get receivables by buyer name
  List<Receivable> getReceivablesByBuyer(String buyerName) {
    return activeReceivables
        .where((r) =>
            r.buyerName.toLowerCase().contains(buyerName.toLowerCase()))
        .toList();
  }

  /// Search receivables
  List<Receivable> searchReceivables(String query) {
    if (query.isEmpty) return activeReceivables;

    final lowerQuery = query.toLowerCase();
    return activeReceivables.where((r) {
      return r.buyerName.toLowerCase().contains(lowerQuery) ||
          (r.phoneNumber?.contains(query) ?? false) ||
          (r.notes?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  /// Get summary by buyer
  Map<String, Map<String, dynamic>> getBuyerSummary() {
    final summary = <String, Map<String, dynamic>>{};

    for (final receivable in activeReceivables) {
      if (!summary.containsKey(receivable.buyerName)) {
        summary[receivable.buyerName] = {
          'total': 0.0,
          'paid': 0.0,
          'remaining': 0.0,
          'count': 0,
        };
      }

      summary[receivable.buyerName]!['total'] =
          (summary[receivable.buyerName]!['total'] as double) +
              receivable.totalAmount;
      summary[receivable.buyerName]!['paid'] =
          (summary[receivable.buyerName]!['paid'] as double) +
              receivable.paidAmount;
      summary[receivable.buyerName]!['remaining'] =
          (summary[receivable.buyerName]!['remaining'] as double) +
              receivable.remainingAmount;
      summary[receivable.buyerName]!['count'] =
          (summary[receivable.buyerName]!['count'] as int) + 1;
    }

    return summary;
  }

  /// Refresh data
  Future<void> refresh() async {
    await loadReceivables();
  }

  // ===== PRIVATE METHODS =====

  void _sortReceivables() {
    _receivables.sort((a, b) {
      // Overdue first
      if (a.isOverdue && !b.isOverdue) return -1;
      if (!a.isOverdue && b.isOverdue) return 1;

      // Then by due date
      if (a.dueDate != null && b.dueDate != null) {
        return a.dueDate!.compareTo(b.dueDate!);
      }
      if (a.dueDate != null) return -1;
      if (b.dueDate != null) return 1;

      // Then by created date
      return b.createdAt.compareTo(a.createdAt);
    });
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setProcessing(bool value) {
    _isProcessing = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  void clearError() {
    _clearError();
    notifyListeners();
  }
}
