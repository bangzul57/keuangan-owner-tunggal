import 'package:flutter/foundation.dart';

import '../core/database/db_helper.dart';
import '../core/database/db_migration.dart';
import '../models/account.dart';

/// Provider untuk mengelola data Akun
class AccountProvider extends ChangeNotifier {
  final DBHelper _dbHelper = DBHelper.instance;

  List<Account> _accounts = [];
  Account? _selectedAccount;
  bool _isLoading = false;
  String? _errorMessage;

  // ===== GETTERS =====

  List<Account> get accounts => List.unmodifiable(_accounts);

  List<Account> get activeAccounts =>
      _accounts.where((a) => a.isActive).toList();

  Account? get selectedAccount => _selectedAccount;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  /// Akun kas (default)
  Account? get cashAccount => _accounts.firstWhere(
        (a) => a.type == AccountType.cash && a.isDefault && a.isActive,
        orElse: () => _accounts.firstWhere(
          (a) => a.type == AccountType.cash && a.isActive,
          orElse: () => _accounts.first,
        ),
      );

  /// Semua akun kas
  List<Account> get cashAccounts =>
      activeAccounts.where((a) => a.type == AccountType.cash).toList();

  /// Semua akun digital (e-wallet)
  List<Account> get digitalAccounts =>
      activeAccounts.where((a) => a.type == AccountType.digital).toList();

  /// Semua akun bank
  List<Account> get bankAccounts =>
      activeAccounts.where((a) => a.type == AccountType.bank).toList();

  /// Semua akun aset (kas + digital + bank)
  List<Account> get assetAccounts =>
      activeAccounts.where((a) => a.type != AccountType.receivable).toList();

  /// Semua akun digital dan bank (untuk transaksi digital)
  List<Account> get digitalAndBankAccounts => activeAccounts
      .where((a) =>
          a.type == AccountType.digital || a.type == AccountType.bank)
      .toList();

  /// Total saldo semua akun aset
  double get totalAssetBalance => assetAccounts.fold(
        0.0,
        (sum, account) => sum + account.balance,
      );

  /// Total saldo kas
  double get totalCashBalance => cashAccounts.fold(
        0.0,
        (sum, account) => sum + account.balance,
      );

  /// Total saldo digital
  double get totalDigitalBalance => digitalAccounts.fold(
        0.0,
        (sum, account) => sum + account.balance,
      );

  // ===== CRUD OPERATIONS =====

  /// Load semua akun dari database
  Future<void> loadAccounts() async {
    _setLoading(true);
    _clearError();

    try {
      final maps = await _dbHelper.queryAll(
        DBMigration.tableAccounts,
        where: 'is_active = ?',
        whereArgs: [1],
        orderBy: 'is_default DESC, name ASC',
      );

      _accounts = maps.map((map) => Account.fromMap(map)).toList();
      notifyListeners();
    } catch (e) {
      _setError('Gagal memuat data akun: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Tambah akun baru
  Future<bool> addAccount(Account account) async {
    _clearError();

    try {
      // Validasi nama tidak duplikat
      final existing = _accounts.where(
        (a) => a.name.toLowerCase() == account.name.toLowerCase() && a.isActive,
      );
      if (existing.isNotEmpty) {
        _setError('Akun dengan nama "${account.name}" sudah ada');
        return false;
      }

      final id = await _dbHelper.insert(
        DBMigration.tableAccounts,
        account.toMap(),
      );

      final newAccount = account.copyWith(id: id);
      _accounts.add(newAccount);
      _sortAccounts();
      notifyListeners();

      return true;
    } catch (e) {
      _setError('Gagal menambah akun: $e');
      return false;
    }
  }

  /// Update akun
  Future<bool> updateAccount(Account account) async {
    _clearError();

    if (account.id == null) {
      _setError('ID akun tidak valid');
      return false;
    }

    try {
      final updatedAccount = account.copyWith(updatedAt: DateTime.now());

      await _dbHelper.updateById(
        DBMigration.tableAccounts,
        account.id!,
        updatedAccount.toMap(),
      );

      final index = _accounts.indexWhere((a) => a.id == account.id);
      if (index != -1) {
        _accounts[index] = updatedAccount;
        _sortAccounts();
        notifyListeners();
      }

      return true;
    } catch (e) {
      _setError('Gagal mengupdate akun: $e');
      return false;
    }
  }

  /// Update saldo akun
  Future<bool> updateBalance(int accountId, double newBalance) async {
    _clearError();

    try {
      final account = getAccountById(accountId);
      if (account == null) {
        _setError('Akun tidak ditemukan');
        return false;
      }

      final updatedAccount = account.copyWith(
        balance: newBalance,
        updatedAt: DateTime.now(),
      );

      await _dbHelper.updateById(
        DBMigration.tableAccounts,
        accountId,
        {'balance': newBalance, 'updated_at': DateTime.now().toIso8601String()},
      );

      final index = _accounts.indexWhere((a) => a.id == accountId);
      if (index != -1) {
        _accounts[index] = updatedAccount;
        notifyListeners();
      }

      return true;
    } catch (e) {
      _setError('Gagal mengupdate saldo: $e');
      return false;
    }
  }

  /// Adjust saldo (tambah/kurang)
  Future<bool> adjustBalance(int accountId, double adjustment) async {
    final account = getAccountById(accountId);
    if (account == null) {
      _setError('Akun tidak ditemukan');
      return false;
    }

    final newBalance = account.balance + adjustment;
    if (newBalance < 0) {
      _setError('Saldo tidak mencukupi');
      return false;
    }

    return updateBalance(accountId, newBalance);
  }

  /// Soft delete akun (set is_active = 0)
  Future<bool> deleteAccount(int accountId) async {
    _clearError();

    try {
      final account = getAccountById(accountId);
      if (account == null) {
        _setError('Akun tidak ditemukan');
        return false;
      }

      if (account.isDefault) {
        _setError('Tidak dapat menghapus akun default');
        return false;
      }

      await _dbHelper.softDelete(DBMigration.tableAccounts, accountId);

      _accounts.removeWhere((a) => a.id == accountId);
      notifyListeners();

      return true;
    } catch (e) {
      _setError('Gagal menghapus akun: $e');
      return false;
    }
  }

  // ===== HELPER METHODS =====

  /// Cari akun berdasarkan ID
  Account? getAccountById(int id) {
    try {
      return _accounts.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Cari akun berdasarkan nama
  Account? getAccountByName(String name) {
    try {
      return _accounts.firstWhere(
        (a) => a.name.toLowerCase() == name.toLowerCase() && a.isActive,
      );
    } catch (_) {
      return null;
    }
  }

  /// Set akun yang dipilih
  void selectAccount(Account? account) {
    _selectedAccount = account;
    notifyListeners();
  }

  /// Cek apakah saldo mencukupi
  bool hasSufficientBalance(int accountId, double amount) {
    final account = getAccountById(accountId);
    return account != null && account.balance >= amount;
  }

  /// Refresh data dari database
  Future<void> refresh() async {
    await loadAccounts();
  }

  // ===== PRIVATE METHODS =====

  void _sortAccounts() {
    _accounts.sort((a, b) {
      // Default account first
      if (a.isDefault && !b.isDefault) return -1;
      if (!a.isDefault && b.isDefault) return 1;
      // Then by type
      final typeCompare = a.type.index.compareTo(b.type.index);
      if (typeCompare != 0) return typeCompare;
      // Then by name
      return a.name.compareTo(b.name);
    });
  }

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
