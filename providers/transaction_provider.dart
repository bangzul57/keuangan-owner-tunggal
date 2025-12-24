import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../core/database/db_helper.dart';
import '../core/database/db_migration.dart';
import '../core/utils/formatters.dart';
import '../models/account.dart';
import '../models/digital_transaction_mode.dart';
import '../models/inventory_item.dart';
import '../models/journal_entry.dart';
import '../models/receivable.dart';
import '../models/transaction_model.dart';
import 'account_provider.dart';
import 'inventory_provider.dart';

/// Provider untuk mengelola Transaksi
/// Ini adalah provider utama yang menangani semua jenis transaksi
class TransactionProvider extends ChangeNotifier {
  final DBHelper _dbHelper = DBHelper.instance;

  // Dependencies (akan di-inject via ProxyProvider)
  AccountProvider? _accountProvider;
  InventoryProvider? _inventoryProvider;

  List<TransactionModel> _transactions = [];
  List<TransactionModel> _filteredTransactions = [];
  bool _isLoading = false;
  bool _isProcessing = false; // Untuk mencegah double-click
  String? _errorMessage;

  // Filter state
  TransactionType? _filterType;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  int? _filterAccountId;

  // ===== DEPENDENCY INJECTION =====

  void updateDependencies(
    AccountProvider accountProvider,
    InventoryProvider inventoryProvider,
  ) {
    _accountProvider = accountProvider;
    _inventoryProvider = inventoryProvider;
  }

  // ===== GETTERS =====

  List<TransactionModel> get transactions => List.unmodifiable(_transactions);

  List<TransactionModel> get filteredTransactions =>
      List.unmodifiable(_filteredTransactions);

  List<TransactionModel> get activeTransactions =>
      _transactions.where((t) => !t.isVoided).toList();

  bool get isLoading => _isLoading;

  bool get isProcessing => _isProcessing;

  String? get errorMessage => _errorMessage;

  bool get hasActiveFilter =>
      _filterType != null ||
      _filterStartDate != null ||
      _filterEndDate != null ||
      _filterAccountId != null;

  /// Total profit dari semua transaksi aktif
  double get totalProfit => activeTransactions.totalProfit;

  /// Total transaksi hari ini
  List<TransactionModel> get todayTransactions {
    final today = DateTime.now();
    return activeTransactions.where((t) {
      return t.transactionDate.year == today.year &&
          t.transactionDate.month == today.month &&
          t.transactionDate.day == today.day;
    }).toList();
  }

  /// Total profit hari ini
  double get todayProfit => todayTransactions.totalProfit;

  /// Transaksi digital
  List<TransactionModel> get digitalTransactions =>
      activeTransactions.byType(TransactionType.digital);

  /// Transaksi retail
  List<TransactionModel> get retailTransactions =>
      activeTransactions.byType(TransactionType.retail);

  // ===== LOAD OPERATIONS =====

  /// Load semua transaksi dari database
  Future<void> loadTransactions() async {
    _setLoading(true);
    _clearError();

    try {
      final maps = await _dbHelper.rawQuery('''
        SELECT 
          t.*,
          sa.name as source_account_name,
          da.name as destination_account_name,
          i.name as inventory_item_name
        FROM ${DBMigration.tableTransactions} t
        LEFT JOIN ${DBMigration.tableAccounts} sa ON t.source_account_id = sa.id
        LEFT JOIN ${DBMigration.tableAccounts} da ON t.destination_account_id = da.id
        LEFT JOIN ${DBMigration.tableInventoryItems} i ON t.inventory_item_id = i.id
        WHERE t.is_voided = 0
        ORDER BY t.transaction_date DESC, t.created_at DESC
      ''');

      _transactions = maps.map((map) => TransactionModel.fromMap(map)).toList();
      _applyFilters();
      notifyListeners();
    } catch (e) {
      _setError('Gagal memuat data transaksi: $e');
    } finally {
      _setLoading(false);
    }
  }

  // ===== DIGITAL TRANSACTION =====

  /// Proses transaksi digital (beli/jual saldo)
  Future<bool> processDigitalTransaction({
    required DigitalTransactionMode mode,
    required int digitalAccountId,
    required int cashAccountId,
    required double amount,
    required double adminFee,
    String? buyerName,
    String? description,
    String? notes,
    bool isCredit = false, // Apakah hutang
    DateTime? dueDate,
  }) async {
    if (_isProcessing) return false;
    _setProcessing(true);
    _clearError();

    try {
      // Validasi
      final digitalAccount = _accountProvider?.getAccountById(digitalAccountId);
      final cashAccount = _accountProvider?.getAccountById(cashAccountId);

      if (digitalAccount == null || cashAccount == null) {
        _setError('Akun tidak ditemukan');
        return false;
      }

      // Hitung profit
      double profit = adminFee;

      // Validasi saldo berdasarkan mode
      switch (mode) {
        case DigitalTransactionMode.buyBalance:
          // Owner mengeluarkan saldo digital, menerima kas
          if (!digitalAccount.hasSufficientBalance(amount)) {
            _setError('Saldo ${digitalAccount.name} tidak mencukupi');
            return false;
          }
          break;

        case DigitalTransactionMode.sellBalanceDeduct:
        case DigitalTransactionMode.sellBalanceCash:
          // Owner mengeluarkan kas, menerima saldo digital
          final cashNeeded = mode == DigitalTransactionMode.sellBalanceDeduct
              ? amount - adminFee
              : amount;
          if (!cashAccount.hasSufficientBalance(cashNeeded)) {
            _setError('Saldo ${cashAccount.name} tidak mencukupi');
            return false;
          }
          break;

        default:
          break;
      }

      // Execute dalam transaction
      await _dbHelper.executeTransaction((txn) async {
        final now = DateTime.now();
        final transactionCode = Formatters.generateTransactionCode('DIG');

        // Hitung perubahan saldo
        double digitalChange = 0;
        double cashChange = 0;

        switch (mode) {
          case DigitalTransactionMode.buyBalance:
            // Pembeli beli saldo dari owner
            digitalChange = -amount; // Digital berkurang
            cashChange = amount + adminFee; // Kas bertambah (nominal + admin)
            break;

          case DigitalTransactionMode.sellBalanceDeduct:
            // Pembeli jual saldo, admin dipotong
            digitalChange = amount; // Digital bertambah
            cashChange = -(amount - adminFee); // Kas berkurang (nominal - admin)
            break;

          case DigitalTransactionMode.sellBalanceCash:
            // Pembeli jual saldo, admin tunai terpisah
            digitalChange = amount; // Digital bertambah
            cashChange = -amount + adminFee; // Kas: -nominal + admin masuk
            break;

          default:
            break;
        }

        // Balance before
        final digitalBalanceBefore = digitalAccount.balance;
        final cashBalanceBefore = cashAccount.balance;

        // Jika bukan hutang, update saldo
        if (!isCredit) {
          // Update saldo digital
          await txn.update(
            DBMigration.tableAccounts,
            {
              'balance': digitalBalanceBefore + digitalChange,
              'updated_at': now.toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [digitalAccountId],
          );

          // Update saldo kas
          await txn.update(
            DBMigration.tableAccounts,
            {
              'balance': cashBalanceBefore + cashChange,
              'updated_at': now.toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [cashAccountId],
          );
        }

        // Insert transaksi
        final transactionId = await txn.insert(
          DBMigration.tableTransactions,
          {
            'transaction_code': transactionCode,
            'transaction_type': TransactionType.digital.value,
            'transaction_mode': mode.value,
            'amount': amount,
            'admin_fee': adminFee,
            'profit': profit,
            'source_account_id': mode.isBuyMode ? digitalAccountId : cashAccountId,
            'destination_account_id': mode.isBuyMode ? cashAccountId : digitalAccountId,
            'buyer_name': buyerName,
            'description': description ?? mode.label,
            'notes': notes,
            'is_credit': isCredit ? 1 : 0,
            'balance_before_source': mode.isBuyMode ? digitalBalanceBefore : cashBalanceBefore,
            'balance_after_source': mode.isBuyMode
                ? digitalBalanceBefore + digitalChange
                : cashBalanceBefore + cashChange,
            'balance_before_dest': mode.isBuyMode ? cashBalanceBefore : digitalBalanceBefore,
            'balance_after_dest': mode.isBuyMode
                ? cashBalanceBefore + cashChange
                : digitalBalanceBefore + digitalChange,
            'transaction_date': now.toIso8601String(),
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          },
        );

        // Jika hutang, buat receivable
        if (isCredit && buyerName != null) {
          await txn.insert(
            DBMigration.tableReceivables,
            {
              'buyer_name': buyerName,
              'total_amount': amount + adminFee,
              'paid_amount': 0,
              'remaining_amount': amount + adminFee,
              'profit_amount': profit,
              'source_transaction_id': transactionId,
              'due_date': dueDate?.toIso8601String(),
              'status': ReceivableStatus.pending.value,
              'notes': notes,
              'is_active': 1,
              'created_at': now.toIso8601String(),
              'updated_at': now.toIso8601String(),
            },
          );

          // Tetap kurangi saldo digital meskipun hutang
          await txn.update(
            DBMigration.tableAccounts,
            {
              'balance': digitalBalanceBefore + digitalChange,
              'updated_at': now.toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [digitalAccountId],
          );
        }

        // Insert journal entries
        await _insertJournalEntries(
          txn: txn,
          transactionId: transactionId,
          entries: [
            // Debit entry
            {
              'transaction_id': transactionId,
              'account_id': mode.isBuyMode ? cashAccountId : digitalAccountId,
              'entry_type': EntryType.debit.value,
              'amount': mode.isBuyMode ? amount + adminFee : amount,
              'balance_before': mode.isBuyMode ? cashBalanceBefore : digitalBalanceBefore,
              'balance_after': mode.isBuyMode
                  ? cashBalanceBefore + cashChange
                  : digitalBalanceBefore + digitalChange,
              'description': '${mode.label} - Debit',
              'created_at': now.toIso8601String(),
            },
            // Credit entry
            {
              'transaction_id': transactionId,
              'account_id': mode.isBuyMode ? digitalAccountId : cashAccountId,
              'entry_type': EntryType.credit.value,
              'amount': amount,
              'balance_before': mode.isBuyMode ? digitalBalanceBefore : cashBalanceBefore,
              'balance_after': mode.isBuyMode
                  ? digitalBalanceBefore + digitalChange
                  : cashBalanceBefore + cashChange,
              'description': '${mode.label} - Credit',
              'created_at': now.toIso8601String(),
            },
          ],
        );
      });

      // Reload data
      await _accountProvider?.loadAccounts();
      await loadTransactions();

      return true;
    } catch (e) {
      _setError('Gagal memproses transaksi: $e');
      return false;
    } finally {
      _setProcessing(false);
    }
  }

  // ===== RETAIL TRANSACTION =====

  /// Proses transaksi retail (jual barang)
  Future<bool> processRetailTransaction({
    required int itemId,
    required int quantity,
    required int destinationAccountId,
    double? customSellPrice,
    String? buyerName,
    String? description,
    String? notes,
    bool isCredit = false,
    DateTime? dueDate,
  }) async {
    if (_isProcessing) return false;
    _setProcessing(true);
    _clearError();

    try {
      // Validasi
      final item = _inventoryProvider?.getItemById(itemId);
      final destAccount = _accountProvider?.getAccountById(destinationAccountId);

      if (item == null) {
        _setError('Barang tidak ditemukan');
        return false;
      }

      if (destAccount == null) {
        _setError('Akun tujuan tidak ditemukan');
        return false;
      }

      if (!item.hasSufficientStock(quantity)) {
        _setError('Stok tidak mencukupi (tersedia: ${item.stock})');
        return false;
      }

      // Hitung harga dan profit
      final sellPrice = customSellPrice ?? item.sellPrice;
      final totalAmount = sellPrice * quantity;
      final totalCost = item.buyPrice * quantity;
      final profit = totalAmount - totalCost;

      // Execute dalam transaction
      await _dbHelper.executeTransaction((txn) async {
        final now = DateTime.now();
        final transactionCode = Formatters.generateTransactionCode('RTL');

        // Balance before
        final destBalanceBefore = destAccount.balance;

        // Update stok
        await txn.update(
          DBMigration.tableInventoryItems,
          {
            'stock': item.stock - quantity,
            'updated_at': now.toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [itemId],
        );

        // Update saldo jika bukan hutang
        if (!isCredit) {
          await txn.update(
            DBMigration.tableAccounts,
            {
              'balance': destBalanceBefore + totalAmount,
              'updated_at': now.toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [destinationAccountId],
          );
        }

        // Insert transaksi
        final transactionId = await txn.insert(
          DBMigration.tableTransactions,
          {
            'transaction_code': transactionCode,
            'transaction_type': TransactionType.retail.value,
            'amount': totalAmount,
            'profit': profit,
            'destination_account_id': destinationAccountId,
            'inventory_item_id': itemId,
            'quantity': quantity,
            'buyer_name': buyerName,
            'description': description ?? 'Penjualan ${item.name}',
            'notes': notes,
            'is_credit': isCredit ? 1 : 0,
            'balance_before_dest': destBalanceBefore,
            'balance_after_dest': isCredit ? destBalanceBefore : destBalanceBefore + totalAmount,
            'transaction_date': now.toIso8601String(),
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          },
        );

        // Jika hutang, buat receivable
        if (isCredit && buyerName != null) {
          await txn.insert(
            DBMigration.tableReceivables,
            {
              'buyer_name': buyerName,
              'total_amount': totalAmount,
              'paid_amount': 0,
              'remaining_amount': totalAmount,
              'profit_amount': profit,
              'source_transaction_id': transactionId,
              'due_date': dueDate?.toIso8601String(),
              'status': ReceivableStatus.pending.value,
              'notes': notes,
              'is_active': 1,
              'created_at': now.toIso8601String(),
              'updated_at': now.toIso8601String(),
            },
          );
        }

        // Insert journal entry (Debit: Kas/Piutang, Credit: Penjualan)
        await _insertJournalEntries(
          txn: txn,
          transactionId: transactionId,
          entries: [
            {
              'transaction_id': transactionId,
              'account_id': destinationAccountId,
              'entry_type': EntryType.debit.value,
              'amount': totalAmount,
              'balance_before': destBalanceBefore,
              'balance_after': isCredit ? destBalanceBefore : destBalanceBefore + totalAmount,
              'description': 'Penjualan ${item.name} x$quantity',
              'created_at': now.toIso8601String(),
            },
          ],
        );
      });

      // Reload data
      await _accountProvider?.loadAccounts();
      await _inventoryProvider?.loadItems();
      await loadTransactions();

      return true;
    } catch (e) {
      _setError('Gagal memproses transaksi: $e');
      return false;
    } finally {
      _setProcessing(false);
    }
  }

  // ===== TRANSFER =====

  /// Proses transfer antar akun
  Future<bool> processTransfer({
    required int sourceAccountId,
    required int destinationAccountId,
    required double amount,
    double adminFee = 0,
    String? description,
    String? notes,
  }) async {
    if (_isProcessing) return false;
    _setProcessing(true);
    _clearError();

    try {
      // Validasi
      if (sourceAccountId == destinationAccountId) {
        _setError('Akun asal dan tujuan tidak boleh sama');
        return false;
      }

      final sourceAccount = _accountProvider?.getAccountById(sourceAccountId);
      final destAccount = _accountProvider?.getAccountById(destinationAccountId);

      if (sourceAccount == null || destAccount == null) {
        _setError('Akun tidak ditemukan');
        return false;
      }

      final totalDeduction = amount + adminFee;
      if (!sourceAccount.hasSufficientBalance(totalDeduction)) {
        _setError('Saldo ${sourceAccount.name} tidak mencukupi');
        return false;
      }

      // Execute dalam transaction
      await _dbHelper.executeTransaction((txn) async {
        final now = DateTime.now();
        final transactionCode = Formatters.generateTransactionCode('TRF');

        final sourceBalanceBefore = sourceAccount.balance;
        final destBalanceBefore = destAccount.balance;

        // Update saldo source (dikurangi amount + admin)
        await txn.update(
          DBMigration.tableAccounts,
          {
            'balance': sourceBalanceBefore - totalDeduction,
            'updated_at': now.toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [sourceAccountId],
        );

        // Update saldo destination (ditambah amount saja, admin hilang)
        await txn.update(
          DBMigration.tableAccounts,
          {
            'balance': destBalanceBefore + amount,
            'updated_at': now.toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [destinationAccountId],
        );

        // Insert transaksi
        final transactionId = await txn.insert(
          DBMigration.tableTransactions,
          {
            'transaction_code': transactionCode,
            'transaction_type': TransactionType.transfer.value,
            'transaction_mode': DigitalTransactionMode.transfer.value,
            'amount': amount,
            'admin_fee': adminFee,
            'profit': -adminFee, // Admin adalah kerugian/biaya
            'source_account_id': sourceAccountId,
            'destination_account_id': destinationAccountId,
            'description': description ??
                'Transfer ${sourceAccount.name} → ${destAccount.name}',
            'notes': notes,
            'balance_before_source': sourceBalanceBefore,
            'balance_after_source': sourceBalanceBefore - totalDeduction,
            'balance_before_dest': destBalanceBefore,
            'balance_after_dest': destBalanceBefore + amount,
            'transaction_date': now.toIso8601String(),
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          },
        );

        // Insert journal entries
        await _insertJournalEntries(
          txn: txn,
          transactionId: transactionId,
          entries: [
            // Debit destination
            {
              'transaction_id': transactionId,
              'account_id': destinationAccountId,
              'entry_type': EntryType.debit.value,
              'amount': amount,
              'balance_before': destBalanceBefore,
              'balance_after': destBalanceBefore + amount,
              'description': 'Transfer masuk dari ${sourceAccount.name}',
              'created_at': now.toIso8601String(),
            },
            // Credit source
            {
              'transaction_id': transactionId,
              'account_id': sourceAccountId,
              'entry_type': EntryType.credit.value,
              'amount': totalDeduction,
              'balance_before': sourceBalanceBefore,
              'balance_after': sourceBalanceBefore - totalDeduction,
              'description': 'Transfer keluar ke ${destAccount.name}',
              'created_at': now.toIso8601String(),
            },
          ],
        );
      });

      // Reload data
      await _accountProvider?.loadAccounts();
      await loadTransactions();

      return true;
    } catch (e) {
      _setError('Gagal memproses transfer: $e');
      return false;
    } finally {
      _setProcessing(false);
    }
  }

  // ===== PRIVE =====

  /// Proses prive (penarikan pribadi)
  Future<bool> processPrive({
    required int sourceAccountId,
    required double amount,
    String? description,
    String? notes,
  }) async {
    if (_isProcessing) return false;
    _setProcessing(true);
    _clearError();

    try {
      final sourceAccount = _accountProvider?.getAccountById(sourceAccountId);

      if (sourceAccount == null) {
        _setError('Akun tidak ditemukan');
        return false;
      }

      if (!sourceAccount.hasSufficientBalance(amount)) {
        _setError('Saldo ${sourceAccount.name} tidak mencukupi');
        return false;
      }

      await _dbHelper.executeTransaction((txn) async {
        final now = DateTime.now();
        final transactionCode = Formatters.generateTransactionCode('PRV');

        final balanceBefore = sourceAccount.balance;

        // Update saldo
        await txn.update(
          DBMigration.tableAccounts,
          {
            'balance': balanceBefore - amount,
            'updated_at': now.toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [sourceAccountId],
        );

        // Insert transaksi
        final transactionId = await txn.insert(
          DBMigration.tableTransactions,
          {
            'transaction_code': transactionCode,
            'transaction_type': TransactionType.prive.value,
            'amount': amount,
            'profit': -amount, // Prive adalah pengurangan modal
            'source_account_id': sourceAccountId,
            'description': description ?? 'Prive dari ${sourceAccount.name}',
            'notes': notes,
            'balance_before_source': balanceBefore,
            'balance_after_source': balanceBefore - amount,
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
            'account_id': sourceAccountId,
            'entry_type': EntryType.credit.value,
            'amount': amount,
            'balance_before': balanceBefore,
            'balance_after': balanceBefore - amount,
            'description': 'Prive',
            'created_at': now.toIso8601String(),
          },
        );
      });

      await _accountProvider?.loadAccounts();
      await loadTransactions();

      return true;
    } catch (e) {
      _setError('Gagal memproses prive: $e');
      return false;
    } finally {
      _setProcessing(false);
    }
  }

  // ===== VOID/CANCEL TRANSACTION =====

  /// Batalkan transaksi (void)
  Future<bool> voidTransaction(int transactionId, String reason) async {
    if (_isProcessing) return false;
    _setProcessing(true);
    _clearError();

    try {
      final transaction = getTransactionById(transactionId);
      if (transaction == null) {
        _setError('Transaksi tidak ditemukan');
        return false;
      }

      if (transaction.isVoided) {
        _setError('Transaksi sudah dibatalkan sebelumnya');
        return false;
      }

      await _dbHelper.executeTransaction((txn) async {
        final now = DateTime.now();

        // Reverse saldo changes
        if (transaction.sourceAccountId != null) {
          final sourceAccount =
              _accountProvider?.getAccountById(transaction.sourceAccountId!);
          if (sourceAccount != null) {
            // Restore balance
            final restoredBalance = transaction.balanceBeforeSource ??
                sourceAccount.balance +
                    (transaction.balanceAfterSource != null
                        ? sourceAccount.balance -
                            transaction.balanceAfterSource!
                        : 0);

            await txn.update(
              DBMigration.tableAccounts,
              {
                'balance': transaction.balanceBeforeSource ?? sourceAccount.balance,
                'updated_at': now.toIso8601String(),
              },
              where: 'id = ?',
              whereArgs: [transaction.sourceAccountId],
            );
          }
        }

        if (transaction.destinationAccountId != null) {
          final destAccount =
              _accountProvider?.getAccountById(transaction.destinationAccountId!);
          if (destAccount != null) {
            await txn.update(
              DBMigration.tableAccounts,
              {
                'balance': transaction.balanceBeforeDest ?? destAccount.balance,
                'updated_at': now.toIso8601String(),
              },
              where: 'id = ?',
              whereArgs: [transaction.destinationAccountId],
            );
          }
        }

        // Restore stok jika transaksi retail
        if (transaction.inventoryItemId != null && transaction.quantity > 0) {
          final item =
              _inventoryProvider?.getItemById(transaction.inventoryItemId!);
          if (item != null) {
            await txn.update(
              DBMigration.tableInventoryItems,
              {
                'stock': item.stock + transaction.quantity,
                'updated_at': now.toIso8601String(),
              },
              where: 'id = ?',
              whereArgs: [transaction.inventoryItemId],
            );
          }
        }

        // Mark transaction as voided
        await txn.update(
          DBMigration.tableTransactions,
          {
            'is_voided': 1,
            'voided_at': now.toIso8601String(),
            'voided_reason': reason,
            'updated_at': now.toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [transactionId],
        );

        // Insert audit log
        await txn.insert(
          DBMigration.tableAuditLogs,
          {
            'table_name': DBMigration.tableTransactions,
            'record_id': transactionId,
            'action': 'void',
            'old_data': transaction.toString(),
            'user_note': reason,
            'created_at': now.toIso8601String(),
          },
        );
      });

      await _accountProvider?.loadAccounts();
      await _inventoryProvider?.loadItems();
      await loadTransactions();

      return true;
    } catch (e) {
      _setError('Gagal membatalkan transaksi: $e');
      return false;
    } finally {
      _setProcessing(false);
    }
  }

  // ===== FILTER OPERATIONS =====

  void setTypeFilter(TransactionType? type) {
    _filterType = type;
    _applyFilters();
    notifyListeners();
  }

  void setDateFilter(DateTime? startDate, DateTime? endDate) {
    _filterStartDate = startDate;
    _filterEndDate = endDate;
    _applyFilters();
    notifyListeners();
  }

  void setAccountFilter(int? accountId) {
    _filterAccountId = accountId;
    _applyFilters();
    notifyListeners();
  }

  void clearFilters() {
    _filterType = null;
    _filterStartDate = null;
    _filterEndDate = null;
    _filterAccountId = null;
    _filteredTransactions = List.from(_transactions);
    notifyListeners();
  }

  void _applyFilters() {
    _filteredTransactions = _transactions.where((t) {
      if (_filterType != null && t.transactionType != _filterType) {
        return false;
      }

      if (_filterStartDate != null) {
        final transDate = DateTime(
          t.transactionDate.year,
          t.transactionDate.month,
          t.transactionDate.day,
        );
        final startDate = DateTime(
          _filterStartDate!.year,
          _filterStartDate!.month,
          _filterStartDate!.day,
        );
        if (transDate.isBefore(startDate)) return false;
      }

      if (_filterEndDate != null) {
        final transDate = DateTime(
          t.transactionDate.year,
          t.transactionDate.month,
          t.transactionDate.day,
        );
        final endDate = DateTime(
          _filterEndDate!.year,
          _filterEndDate!.month,
          _filterEndDate!.day,
        );
        if (transDate.isAfter(endDate)) return false;
      }

      if (_filterAccountId != null) {
        if (t.sourceAccountId != _filterAccountId &&
            t.destinationAccountId != _filterAccountId) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  // ===== HELPER METHODS =====

  TransactionModel? getTransactionById(int id) {
    try {
      return _transactions.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> refresh() async {
    await loadTransactions();
  }

  // ===== PRIVATE METHODS =====

  Future<void> _insertJournalEntries({
    required Transaction txn,
    required int transactionId,
    required List<Map<String, dynamic>> entries,
  }) async {
    for (final entry in entries) {
      await txn.insert(DBMigration.tableJournalEntries, entry);
    }
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
