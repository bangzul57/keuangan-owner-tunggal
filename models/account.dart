/// Model untuk Akun (Kas, E-Wallet, Bank, Piutang)
/// Merepresentasikan berbagai jenis akun dalam sistem ledger
class Account {
  final int? id;
  final String name;
  final AccountType type;
  final double balance;
  final double initialBalance;
  final String? icon;
  final String? color;
  final String? description;
  final bool isActive;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Account({
    this.id,
    required this.name,
    required this.type,
    this.balance = 0,
    this.initialBalance = 0,
    this.icon,
    this.color,
    this.description,
    this.isActive = true,
    this.isDefault = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Cek apakah akun adalah kas
  bool get isCash => type == AccountType.cash;

  /// Cek apakah akun adalah digital/e-wallet
  bool get isDigital => type == AccountType.digital;

  /// Cek apakah akun adalah bank
  bool get isBank => type == AccountType.bank;

  /// Cek apakah akun adalah piutang
  bool get isReceivable => type == AccountType.receivable;

  /// Cek apakah saldo mencukupi untuk transaksi
  bool hasSufficientBalance(double amount) => balance >= amount;

  /// Hitung selisih dari saldo awal
  double get balanceDifference => balance - initialBalance;

  /// Copy with untuk immutability
  Account copyWith({
    int? id,
    String? name,
    AccountType? type,
    double? balance,
    double? initialBalance,
    String? icon,
    String? color,
    String? description,
    bool? isActive,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      initialBalance: initialBalance ?? this.initialBalance,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Convert ke Map untuk database
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'type': type.value,
      'balance': balance,
      'initial_balance': initialBalance,
      'icon': icon,
      'color': color,
      'description': description,
      'is_active': isActive ? 1 : 0,
      'is_default': isDefault ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Convert dari Map database
  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: AccountType.fromValue(map['type'] as String),
      balance: (map['balance'] as num?)?.toDouble() ?? 0,
      initialBalance: (map['initial_balance'] as num?)?.toDouble() ?? 0,
      icon: map['icon'] as String?,
      color: map['color'] as String?,
      description: map['description'] as String?,
      isActive: (map['is_active'] as int?) == 1,
      isDefault: (map['is_default'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// Factory untuk membuat akun baru
  factory Account.create({
    required String name,
    required AccountType type,
    double initialBalance = 0,
    String? icon,
    String? color,
    String? description,
  }) {
    final now = DateTime.now();
    return Account(
      name: name,
      type: type,
      balance: initialBalance,
      initialBalance: initialBalance,
      icon: icon,
      color: color,
      description: description,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  String toString() {
    return 'Account(id: $id, name: $name, type: ${type.value}, balance: $balance)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Account && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Enum untuk tipe akun
enum AccountType {
  cash('cash', 'Kas'),
  digital('digital', 'E-Wallet'),
  bank('bank', 'Bank'),
  receivable('receivable', 'Piutang');

  final String value;
  final String label;

  const AccountType(this.value, this.label);

  /// Convert dari string value
  static AccountType fromValue(String value) {
    return AccountType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AccountType.cash,
    );
  }

  /// Cek apakah tipe ini bisa untuk transaksi digital
  bool get canDigitalTransaction {
    return this == AccountType.digital || this == AccountType.bank;
  }

  /// Cek apakah tipe ini adalah aset (bukan piutang)
  bool get isAsset {
    return this != AccountType.receivable;
  }
}
