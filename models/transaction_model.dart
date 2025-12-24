import 'digital_transaction_mode.dart';

/// Model untuk Transaksi
/// Merepresentasikan semua jenis transaksi dalam sistem
class TransactionModel {
  final int? id;
  final String? transactionCode;
  final TransactionType transactionType;
  final DigitalTransactionMode? transactionMode;
  final double amount;
  final double adminFee;
  final double profit;
  final int? sourceAccountId;
  final int? destinationAccountId;
  final int? inventoryItemId;
  final int quantity;
  final String? buyerName;
  final String? description;
  final String? notes;
  final bool isCredit; // Apakah ini transaksi hutang/piutang
  final int? receivableId;
  final double? balanceBeforeSource;
  final double? balanceAfterSource;
  final double? balanceBeforeDest;
  final double? balanceAfterDest;
  final bool isVoided;
  final DateTime? voidedAt;
  final String? voidedReason;
  final DateTime transactionDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Fields untuk join (tidak disimpan di DB)
  final String? sourceAccountName;
  final String? destinationAccountName;
  final String? inventoryItemName;

  const TransactionModel({
    this.id,
    this.transactionCode,
    required this.transactionType,
    this.transactionMode,
    required this.amount,
    this.adminFee = 0,
    this.profit = 0,
    this.sourceAccountId,
    this.destinationAccountId,
    this.inventoryItemId,
    this.quantity = 1,
    this.buyerName,
    this.description,
    this.notes,
    this.isCredit = false,
    this.receivableId,
    this.balanceBeforeSource,
    this.balanceAfterSource,
    this.balanceBeforeDest,
    this.balanceAfterDest,
    this.isVoided = false,
    this.voidedAt,
    this.voidedReason,
    required this.transactionDate,
    required this.createdAt,
    required this.updatedAt,
    this.sourceAccountName,
    this.destinationAccountName,
    this.inventoryItemName,
  });

  /// Total amount termasuk admin fee
  double get totalAmount => amount + adminFee;

  /// Cek apakah transaksi ini adalah transaksi digital
  bool get isDigitalTransaction => transactionType == TransactionType.digital;

  /// Cek apakah transaksi ini adalah transaksi ritel
  bool get isRetailTransaction => transactionType == TransactionType.retail;

  /// Cek apakah transaksi ini adalah transfer
  bool get isTransfer => transactionType == TransactionType.transfer;

  /// Cek apakah transaksi ini adalah prive
  bool get isPrive => transactionType == TransactionType.prive;

  /// Cek apakah transaksi ini sudah dibatalkan
  bool get isCancelled => isVoided;

  /// Cek apakah transaksi ini adalah hutang
  bool get isReceivable => isCredit;

  /// Copy with untuk immutability
  TransactionModel copyWith({
    int? id,
    String? transactionCode,
    TransactionType? transactionType,
    DigitalTransactionMode? transactionMode,
    double? amount,
    double? adminFee,
    double? profit,
    int? sourceAccountId,
    int? destinationAccountId,
    int? inventoryItemId,
    int? quantity,
    String? buyerName,
    String? description,
    String? notes,
    bool? isCredit,
    int? receivableId,
    double? balanceBeforeSource,
    double? balanceAfterSource,
    double? balanceBeforeDest,
    double? balanceAfterDest,
    bool? isVoided,
    DateTime? voidedAt,
    String? voidedReason,
    DateTime? transactionDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? sourceAccountName,
    String? destinationAccountName,
    String? inventoryItemName,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      transactionCode: transactionCode ?? this.transactionCode,
      transactionType: transactionType ?? this.transactionType,
      transactionMode: transactionMode ?? this.transactionMode,
      amount: amount ?? this.amount,
      adminFee: adminFee ?? this.adminFee,
      profit: profit ?? this.profit,
      sourceAccountId: sourceAccountId ?? this.sourceAccountId,
      destinationAccountId: destinationAccountId ?? this.destinationAccountId,
      inventoryItemId: inventoryItemId ?? this.inventoryItemId,
      quantity: quantity ?? this.quantity,
      buyerName: buyerName ?? this.buyerName,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      isCredit: isCredit ?? this.isCredit,
      receivableId: receivableId ?? this.receivableId,
      balanceBeforeSource: balanceBeforeSource ?? this.balanceBeforeSource,
      balanceAfterSource: balanceAfterSource ?? this.balanceAfterSource,
      balanceBeforeDest: balanceBeforeDest ?? this.balanceBeforeDest,
      balanceAfterDest: balanceAfterDest ?? this.balanceAfterDest,
      isVoided: isVoided ?? this.isVoided,
      voidedAt: voidedAt ?? this.voidedAt,
      voidedReason: voidedReason ?? this.voidedReason,
      transactionDate: transactionDate ?? this.transactionDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sourceAccountName: sourceAccountName ?? this.sourceAccountName,
      destinationAccountName: destinationAccountName ?? this.destinationAccountName,
      inventoryItemName: inventoryItemName ?? this.inventoryItemName,
    );
  }

  /// Convert ke Map untuk database
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'transaction_code': transactionCode,
      'transaction_type': transactionType.value,
      'transaction_mode': transactionMode?.value,
      'amount': amount,
      'admin_fee': adminFee,
      'profit': profit,
      'source_account_id': sourceAccountId,
      'destination_account_id': destinationAccountId,
      'inventory_item_id': inventoryItemId,
      'quantity': quantity,
      'buyer_name': buyerName,
      'description': description,
      'notes': notes,
      'is_credit': isCredit ? 1 : 0,
      'receivable_id': receivableId,
      'balance_before_source': balanceBeforeSource,
      'balance_after_source': balanceAfterSource,
      'balance_before_dest': balanceBeforeDest,
      'balance_after_dest': balanceAfterDest,
      'is_voided': isVoided ? 1 : 0,
      'voided_at': voidedAt?.toIso8601String(),
      'voided_reason': voidedReason,
      'transaction_date': transactionDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Convert dari Map database
  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as int?,
      transactionCode: map['transaction_code'] as String?,
      transactionType: TransactionType.fromValue(map['transaction_type'] as String),
      transactionMode: map['transaction_mode'] != null
          ? DigitalTransactionMode.fromValue(map['transaction_mode'] as String)
          : null,
      amount: (map['amount'] as num).toDouble(),
      adminFee: (map['admin_fee'] as num?)?.toDouble() ?? 0,
      profit: (map['profit'] as num?)?.toDouble() ?? 0,
      sourceAccountId: map['source_account_id'] as int?,
      destinationAccountId: map['destination_account_id'] as int?,
      inventoryItemId: map['inventory_item_id'] as int?,
      quantity: (map['quantity'] as int?) ?? 1,
      buyerName: map['buyer_name'] as String?,
      description: map['description'] as String?,
      notes: map['notes'] as String?,
      isCredit: (map['is_credit'] as int?) == 1,
      receivableId: map['receivable_id'] as int?,
      balanceBeforeSource: (map['balance_before_source'] as num?)?.toDouble(),
      balanceAfterSource: (map['balance_after_source'] as num?)?.toDouble(),
      balanceBeforeDest: (map['balance_before_dest'] as num?)?.toDouble(),
      balanceAfterDest: (map['balance_after_dest'] as num?)?.toDouble(),
      isVoided: (map['is_voided'] as int?) == 1,
      voidedAt: map['voided_at'] != null
          ? DateTime.parse(map['voided_at'] as String)
          : null,
      voidedReason: map['voided_reason'] as String?,
      transactionDate: DateTime.parse(map['transaction_date'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      // Fields dari join
      sourceAccountName: map['source_account_name'] as String?,
      destinationAccountName: map['destination_account_name'] as String?,
      inventoryItemName: map['inventory_item_name'] as String?,
    );
  }

  @override
  String toString() {
    return 'TransactionModel(id: $id, code: $transactionCode, '
        'type: ${transactionType.value}, amount: $amount, profit: $profit)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TransactionModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Enum untuk tipe transaksi
enum TransactionType {
  digital('digital', 'Transaksi Digital'),
  retail('retail', 'Transaksi Ritel'),
  transfer('transfer', 'Transfer'),
  prive('prive', 'Prive'),
  adjustment('adjustment', 'Penyesuaian'),
  receivablePayment('receivable_payment', 'Pembayaran Piutang');

  final String value;
  final String label;

  const TransactionType(this.value, this.label);

  static TransactionType fromValue(String value) {
    return TransactionType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TransactionType.digital,
    );
  }

  /// Mendapatkan icon untuk tipe transaksi
  String get iconName {
    switch (this) {
      case TransactionType.digital:
        return 'smartphone';
      case TransactionType.retail:
        return 'store';
      case TransactionType.transfer:
        return 'swap_horiz';
      case TransactionType.prive:
        return 'account_balance_wallet';
      case TransactionType.adjustment:
        return 'tune';
      case TransactionType.receivablePayment:
        return 'payments';
    }
  }
}

/// Extension untuk list of TransactionModel
extension TransactionListExt on List<TransactionModel> {
  /// Total profit
  double get totalProfit {
    return where((t) => !t.isVoided).fold(0.0, (sum, t) => sum + t.profit);
  }

  /// Total amount
  double get totalAmount {
    return where((t) => !t.isVoided).fold(0.0, (sum, t) => sum + t.amount);
  }

  /// Filter transaksi yang belum dibatalkan
  List<TransactionModel> get activeOnly {
    return where((t) => !t.isVoided).toList();
  }

  /// Filter by type
  List<TransactionModel> byType(TransactionType type) {
    return where((t) => t.transactionType == type).toList();
  }

  /// Filter by date range
  List<TransactionModel> inDateRange(DateTime start, DateTime end) {
    return where((t) =>
        t.transactionDate.isAfter(start.subtract(const Duration(days: 1))) &&
        t.transactionDate.isBefore(end.add(const Duration(days: 1)))).toList();
  }
}
