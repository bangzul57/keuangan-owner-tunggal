/// Model untuk User Settings
/// Menyimpan preferensi dan konfigurasi pengguna
class UserSettings {
  final bool isDarkMode;
  final bool isDigitalEnabled;
  final bool isRetailEnabled;
  final double defaultAdminFee;
  final double defaultAdminPercentage;
  final bool usePercentageAdmin;
  final int lowStockThreshold;
  final String currencySymbol;
  final String dateFormat;

  const UserSettings({
    this.isDarkMode = false,
    this.isDigitalEnabled = true,
    this.isRetailEnabled = true,
    this.defaultAdminFee = 2500,
    this.defaultAdminPercentage = 2.5,
    this.usePercentageAdmin = false,
    this.lowStockThreshold = 5,
    this.currencySymbol = 'Rp',
    this.dateFormat = 'dd/MM/yyyy',
  });

  /// Mendapatkan mode operasi aplikasi
  AppMode get appMode {
    if (isDigitalEnabled && isRetailEnabled) {
      return AppMode.hybrid;
    } else if (isDigitalEnabled) {
      return AppMode.digitalOnly;
    } else if (isRetailEnabled) {
      return AppMode.retailOnly;
    }
    return AppMode.hybrid; // Default
  }

  /// Hitung admin fee berdasarkan amount
  double calculateAdminFee(double amount) {
    if (usePercentageAdmin) {
      return amount * (defaultAdminPercentage / 100);
    }
    return defaultAdminFee;
  }

  /// Copy with untuk immutability
  UserSettings copyWith({
    bool? isDarkMode,
    bool? isDigitalEnabled,
    bool? isRetailEnabled,
    double? defaultAdminFee,
    double? defaultAdminPercentage,
    bool? usePercentageAdmin,
    int? lowStockThreshold,
    String? currencySymbol,
    String? dateFormat,
  }) {
    return UserSettings(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      isDigitalEnabled: isDigitalEnabled ?? this.isDigitalEnabled,
      isRetailEnabled: isRetailEnabled ?? this.isRetailEnabled,
      defaultAdminFee: defaultAdminFee ?? this.defaultAdminFee,
      defaultAdminPercentage: defaultAdminPercentage ?? this.defaultAdminPercentage,
      usePercentageAdmin: usePercentageAdmin ?? this.usePercentageAdmin,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      dateFormat: dateFormat ?? this.dateFormat,
    );
  }

  /// Convert ke Map untuk database (key-value pairs)
  Map<String, String> toSettingsMap() {
    return {
      'is_dark_mode': isDarkMode.toString(),
      'is_digital_enabled': isDigitalEnabled.toString(),
      'is_retail_enabled': isRetailEnabled.toString(),
      'default_admin_fee': defaultAdminFee.toString(),
      'default_admin_percentage': defaultAdminPercentage.toString(),
      'use_percentage_admin': usePercentageAdmin.toString(),
      'low_stock_threshold': lowStockThreshold.toString(),
      'currency_symbol': currencySymbol,
      'date_format': dateFormat,
    };
  }

  /// Convert dari Map database
  factory UserSettings.fromSettingsMap(Map<String, String> map) {
    return UserSettings(
      isDarkMode: map['is_dark_mode'] == 'true',
      isDigitalEnabled: map['is_digital_enabled'] != 'false',
      isRetailEnabled: map['is_retail_enabled'] != 'false',
      defaultAdminFee: double.tryParse(map['default_admin_fee'] ?? '') ?? 2500,
      defaultAdminPercentage:
          double.tryParse(map['default_admin_percentage'] ?? '') ?? 2.5,
      usePercentageAdmin: map['use_percentage_admin'] == 'true',
      lowStockThreshold: int.tryParse(map['low_stock_threshold'] ?? '') ?? 5,
      currencySymbol: map['currency_symbol'] ?? 'Rp',
      dateFormat: map['date_format'] ?? 'dd/MM/yyyy',
    );
  }

  /// Default settings
  factory UserSettings.defaults() {
    return const UserSettings();
  }

  @override
  String toString() {
    return 'UserSettings(mode: ${appMode.label}, darkMode: $isDarkMode, '
        'adminFee: $defaultAdminFee, adminPercentage: $defaultAdminPercentage%)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserSettings &&
        other.isDarkMode == isDarkMode &&
        other.isDigitalEnabled == isDigitalEnabled &&
        other.isRetailEnabled == isRetailEnabled &&
        other.defaultAdminFee == defaultAdminFee &&
        other.defaultAdminPercentage == defaultAdminPercentage &&
        other.usePercentageAdmin == usePercentageAdmin &&
        other.lowStockThreshold == lowStockThreshold &&
        other.currencySymbol == currencySymbol &&
        other.dateFormat == dateFormat;
  }

  @override
  int get hashCode => Object.hash(
        isDarkMode,
        isDigitalEnabled,
        isRetailEnabled,
        defaultAdminFee,
        defaultAdminPercentage,
        usePercentageAdmin,
        lowStockThreshold,
        currencySymbol,
        dateFormat,
      );
}

/// Enum untuk mode aplikasi
enum AppMode {
  digitalOnly('digital_only', 'Mode Digital'),
  retailOnly('retail_only', 'Mode Ritel'),
  hybrid('hybrid', 'Mode Hybrid');

  final String value;
  final String label;

  const AppMode(this.value, this.label);

  static AppMode fromValue(String value) {
    return AppMode.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AppMode.hybrid,
    );
  }

  /// Deskripsi mode
  String get description {
    switch (this) {
      case AppMode.digitalOnly:
        return 'Hanya fitur transaksi digital (e-wallet, transfer, dll)';
      case AppMode.retailOnly:
        return 'Hanya fitur transaksi ritel (penjualan barang)';
      case AppMode.hybrid:
        return 'Semua fitur digital dan ritel terintegrasi';
    }
  }
}
