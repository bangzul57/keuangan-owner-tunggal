/// Model untuk Journal Entry (Jurnal Double-Entry)
/// Setiap transaksi menghasilkan minimal 2 journal entry (debit & credit)
class JournalEntry {
  final int? id;
  final int transactionId;
  final int accountId;
  final EntryType entryType;
  final double amount;
  final double balanceBefore;
  final double balanceAfter;
  final String? description;
  final DateTime createdAt;

  // Fields untuk join dengan tabel lain (tidak disimpan di DB)
  final String? accountName;
  final String? accountType;
  final String? transactionCode;

  const JournalEntry({
    this.id,
    required this.transactionId,
    required this.accountId,
    required this.entryType,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    this.description,
    required this.createdAt,
    this.accountName,
    this.accountType,
    this.transactionCode,
  });

  /// Cek apakah entry ini adalah debit
  bool get isDebit => entryType == EntryType.debit;

  /// Cek apakah entry ini adalah credit
  bool get isCredit => entryType == EntryType.credit;

  /// Hitung selisih saldo (change)
  double get balanceChange => balanceAfter - balanceBefore;

  /// Copy with untuk immutability
  JournalEntry copyWith({
    int? id,
    int? transactionId,
    int? accountId,
    EntryType? entryType,
    double? amount,
    double? balanceBefore,
    double? balanceAfter,
    String? description,
    DateTime? createdAt,
    String? accountName,
    String? accountType,
    String? transactionCode,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      accountId: accountId ?? this.accountId,
      entryType: entryType ?? this.entryType,
      amount: amount ?? this.amount,
      balanceBefore: balanceBefore ?? this.balanceBefore,
      balanceAfter: balanceAfter ?? this.balanceAfter,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      accountName: accountName ?? this.accountName,
      accountType: accountType ?? this.accountType,
      transactionCode: transactionCode ?? this.transactionCode,
    );
  }

  /// Convert ke Map untuk database
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'transaction_id': transactionId,
      'account_id': accountId,
      'entry_type': entryType.value,
      'amount': amount,
      'balance_before': balanceBefore,
      'balance_after': balanceAfter,
      'description': description,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Convert dari Map database
  factory JournalEntry.fromMap(Map<String, dynamic> map) {
    return JournalEntry(
      id: map['id'] as int?,
      transactionId: map['transaction_id'] as int,
      accountId: map['account_id'] as int,
      entryType: EntryType.fromValue(map['entry_type'] as String),
      amount: (map['amount'] as num).toDouble(),
      balanceBefore: (map['balance_before'] as num).toDouble(),
      balanceAfter: (map['balance_after'] as num).toDouble(),
      description: map['description'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      // Fields dari join (opsional)
      accountName: map['account_name'] as String?,
      accountType: map['account_type'] as String?,
      transactionCode: map['transaction_code'] as String?,
    );
  }

  /// Factory untuk membuat debit entry
  factory JournalEntry.debit({
    required int transactionId,
    required int accountId,
    required double amount,
    required double balanceBefore,
    String? description,
  }) {
    return JournalEntry(
      transactionId: transactionId,
      accountId: accountId,
      entryType: EntryType.debit,
      amount: amount,
      balanceBefore: balanceBefore,
      balanceAfter: balanceBefore + amount, // Debit menambah saldo aset
      description: description,
      createdAt: DateTime.now(),
    );
  }

  /// Factory untuk membuat credit entry
  factory JournalEntry.credit({
    required int transactionId,
    required int accountId,
    required double amount,
    required double balanceBefore,
    String? description,
  }) {
    return JournalEntry(
      transactionId: transactionId,
      accountId: accountId,
      entryType: EntryType.credit,
      amount: amount,
      balanceBefore: balanceBefore,
      balanceAfter: balanceBefore - amount, // Credit mengurangi saldo aset
      description: description,
      createdAt: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'JournalEntry(id: $id, transactionId: $transactionId, '
        'accountId: $accountId, type: ${entryType.value}, amount: $amount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is JournalEntry && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Enum untuk tipe entry (Debit/Credit)
enum EntryType {
  debit('debit', 'Debit'),
  credit('credit', 'Credit');

  final String value;
  final String label;

  const EntryType(this.value, this.label);

  static EntryType fromValue(String value) {
    return EntryType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => EntryType.debit,
    );
  }

  /// Mendapatkan tipe kebalikannya
  EntryType get opposite {
    return this == EntryType.debit ? EntryType.credit : EntryType.debit;
  }
}

/// Extension untuk list of JournalEntry
extension JournalEntryListExt on List<JournalEntry> {
  /// Total debit
  double get totalDebit {
    return where((e) => e.isDebit).fold(0.0, (sum, e) => sum + e.amount);
  }

  /// Total credit
  double get totalCredit {
    return where((e) => e.isCredit).fold(0.0, (sum, e) => sum + e.amount);
  }

  /// Cek apakah balance (debit = credit)
  bool get isBalanced => totalDebit == totalCredit;

  /// Filter by account
  List<JournalEntry> forAccount(int accountId) {
    return where((e) => e.accountId == accountId).toList();
  }

  /// Filter by transaction
  List<JournalEntry> forTransaction(int transactionId) {
    return where((e) => e.transactionId == transactionId).toList();
  }
}
