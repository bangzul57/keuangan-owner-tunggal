import 'package:flutter/foundation.dart';

import '../core/database/db_helper.dart';
import '../core/database/db_migration.dart';
import '../models/user_settings.dart';

/// Provider untuk mengelola pengaturan aplikasi
class SettingsProvider extends ChangeNotifier {
  final DBHelper _dbHelper = DBHelper.instance;

  UserSettings _settings = const UserSettings();
  bool _isLoading = false;
  String? _errorMessage;

  // ===== GETTERS =====

  UserSettings get settings => _settings;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  // Shortcut getters
  bool get isDarkMode => _settings.isDarkMode;

  bool get isDigitalEnabled => _settings.isDigitalEnabled;

  bool get isRetailEnabled => _settings.isRetailEnabled;

  double get defaultAdminFee => _settings.defaultAdminFee;

  double get defaultAdminPercentage => _settings.defaultAdminPercentage;

  bool get usePercentageAdmin => _settings.usePercentageAdmin;

  int get lowStockThreshold => _settings.lowStockThreshold;

  String get currencySymbol => _settings.currencySymbol;

  String get dateFormat => _settings.dateFormat;

  AppMode get appMode => _settings.appMode;

  /// Cek apakah mode hybrid (digital + retail)
  bool get isHybridMode => isDigitalEnabled && isRetailEnabled;

  /// Cek apakah hanya mode digital
  bool get isDigitalOnlyMode => isDigitalEnabled && !isRetailEnabled;

  /// Cek apakah hanya mode retail
  bool get isRetailOnlyMode => !isDigitalEnabled && isRetailEnabled;

  // ===== LOAD & SAVE OPERATIONS =====

  /// Load settings dari database
  Future<void> loadSettings() async {
    _setLoading(true);
    _clearError();

    try {
      final maps = await _dbHelper.queryAll(DBMigration.tableSettings);

      if (maps.isEmpty) {
        // Gunakan default settings jika belum ada data
        _settings = const UserSettings();
      } else {
        // Convert list ke map
        final settingsMap = <String, String>{};
        for (final row in maps) {
          final key = row['key'] as String;
          final value = row['value'] as String?;
          if (value != null) {
            settingsMap[key] = value;
          }
        }
        _settings = UserSettings.fromSettingsMap(settingsMap);
      }

      notifyListeners();
    } catch (e) {
      _setError('Gagal memuat pengaturan: $e');
      _settings = const UserSettings(); // Fallback ke default
    } finally {
      _setLoading(false);
    }
  }

  /// Simpan semua settings ke database
  Future<bool> saveSettings(UserSettings settings) async {
    _clearError();

    try {
      final settingsMap = settings.toSettingsMap();
      final now = DateTime.now().toIso8601String();

      for (final entry in settingsMap.entries) {
        // Cek apakah setting sudah ada
        final existing = await _dbHelper.queryWhere(
          DBMigration.tableSettings,
          where: 'key = ?',
          whereArgs: [entry.key],
        );

        if (existing.isEmpty) {
          // Insert baru
          await _dbHelper.insert(DBMigration.tableSettings, {
            'key': entry.key,
            'value': entry.value,
            'updated_at': now,
          });
        } else {
          // Update existing
          await _dbHelper.update(
            DBMigration.tableSettings,
            {'value': entry.value, 'updated_at': now},
            where: 'key = ?',
            whereArgs: [entry.key],
          );
        }
      }

      _settings = settings;
      notifyListeners();

      return true;
    } catch (e) {
      _setError('Gagal menyimpan pengaturan: $e');
      return false;
    }
  }

  /// Simpan satu setting ke database
  Future<bool> saveSetting(String key, String value) async {
    _clearError();

    try {
      final now = DateTime.now().toIso8601String();

      final existing = await _dbHelper.queryWhere(
        DBMigration.tableSettings,
        where: 'key = ?',
        whereArgs: [key],
      );

      if (existing.isEmpty) {
        await _dbHelper.insert(DBMigration.tableSettings, {
          'key': key,
          'value': value,
          'updated_at': now,
        });
      } else {
        await _dbHelper.update(
          DBMigration.tableSettings,
          {'value': value, 'updated_at': now},
          where: 'key = ?',
          whereArgs: [key],
        );
      }

      // Reload settings
      await loadSettings();

      return true;
    } catch (e) {
      _setError('Gagal menyimpan pengaturan: $e');
      return false;
    }
  }

  // ===== UPDATE INDIVIDUAL SETTINGS =====

  /// Toggle dark mode
  Future<bool> toggleDarkMode() async {
    return saveSetting('is_dark_mode', (!isDarkMode).toString());
  }

  /// Set dark mode
  Future<bool> setDarkMode(bool value) async {
    return saveSetting('is_dark_mode', value.toString());
  }

  /// Toggle digital mode
  Future<bool> toggleDigitalMode() async {
    // Pastikan minimal satu mode aktif
    if (isDigitalEnabled && !isRetailEnabled) {
      _setError('Minimal satu mode harus aktif');
      return false;
    }
    return saveSetting('is_digital_enabled', (!isDigitalEnabled).toString());
  }

  /// Set digital mode
  Future<bool> setDigitalMode(bool value) async {
    // Pastikan minimal satu mode aktif
    if (!value && !isRetailEnabled) {
      _setError('Minimal satu mode harus aktif');
      return false;
    }
    return saveSetting('is_digital_enabled', value.toString());
  }

  /// Toggle retail mode
  Future<bool> toggleRetailMode() async {
    // Pastikan minimal satu mode aktif
    if (isRetailEnabled && !isDigitalEnabled) {
      _setError('Minimal satu mode harus aktif');
      return false;
    }
    return saveSetting('is_retail_enabled', (!isRetailEnabled).toString());
  }

  /// Set retail mode
  Future<bool> setRetailMode(bool value) async {
    // Pastikan minimal satu mode aktif
    if (!value && !isDigitalEnabled) {
      _setError('Minimal satu mode harus aktif');
      return false;
    }
    return saveSetting('is_retail_enabled', value.toString());
  }

  /// Set default admin fee
  Future<bool> setDefaultAdminFee(double fee) async {
    if (fee < 0) {
      _setError('Biaya admin tidak boleh negatif');
      return false;
    }
    return saveSetting('default_admin_fee', fee.toString());
  }

  /// Set default admin percentage
  Future<bool> setDefaultAdminPercentage(double percentage) async {
    if (percentage < 0 || percentage > 100) {
      _setError('Persentase admin harus antara 0-100');
      return false;
    }
    return saveSetting('default_admin_percentage', percentage.toString());
  }

  /// Set use percentage admin
  Future<bool> setUsePercentageAdmin(bool value) async {
    return saveSetting('use_percentage_admin', value.toString());
  }

  /// Set low stock threshold
  Future<bool> setLowStockThreshold(int threshold) async {
    if (threshold < 0) {
      _setError('Batas stok tidak boleh negatif');
      return false;
    }
    return saveSetting('low_stock_threshold', threshold.toString());
  }

  // ===== HELPER METHODS =====

  /// Hitung admin fee berdasarkan nominal
  double calculateAdminFee(double amount) {
    return _settings.calculateAdminFee(amount);
  }

  /// Refresh settings dari database
  Future<void> refresh() async {
    await loadSettings();
  }

  /// Reset ke default settings
  Future<bool> resetToDefaults() async {
    return saveSettings(const UserSettings());
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
