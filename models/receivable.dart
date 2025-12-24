/// Model untuk Piutang (Receivable)
/// Mencatat hutang pembeli yang belum dibayar
class Receivable {
  final int? id;
  final String buyerName;
  final String? phoneNumber;
  final double totalAmount;
  final double paidAmount;
  final double remainingAmount;
  final double profitAmount;
  final int? sourceTransactionId;
  final DateTime? dueDate;
  final ReceivableStatus status;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Fields untuk join (tidak disimpan di DB)
  final List<ReceivablePayment>? payments;

  const Receivable({
    this.id,
    required this.buyerName,
    this.phoneNumber,
    required this.totalAmount,
    this.paidAmount = 0,
    required this.remainingAmount,
    this.profitAmount = 0,
    this.sourceTransactionId,
    this.dueDate,
    this.status = ReceivableStatus.pending,
    this.notes,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.payments,
  });

  /// Cek apakah sudah lunas
  bool get isPaid => status == ReceivableStatus.paid || remainingAmount <= 0;

  /// Cek apakah sudah jatuh tempo
  bool get isOverdue {
    if (dueDate == null || isPaid) return false;
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final dueOnly = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    return dueOnly.isBefore(todayOnly);
  }

  /// Cek apakah jatuh tempo hari ini
  bool get isDueToday {
    if (dueDate == null || isPaid) return false;
    final today = DateTime.now();
    return dueDate!.year == today.year &&
        dueDate!.month == today.month &&
        dueDate!.day == today.day;
  }

  /// Hitung persentase pembayaran
  double get paymentPercentage {
    if (totalAmount <= 0) return 0;
    return (paidAmount / totalAmount) * 100;
  }

  /// Hitung hari tersisa sampai jatuh tempo
  int? get daysUntilDue {
    if (dueDate == null) return null;
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final dueOnly = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    return dueOnly.difference(todayOnly).inDays;
  }

  /// Copy with untuk immutability
  Receivable copyWith({
    int? id,
    String? buyerName,
    String? phoneNumber,
    double? totalAmount,
    double? paidAmount,
    double? remainingAmount,
    double? profitAmount,
    int? sourceTransactionId,
    DateTime? dueDate,
    ReceivableStatus? status,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ReceivablePayment>? payments,
  }) {
    return Receivable(
      id: id ?? this.id,
      buyerName: buyerName ?? this.buyerName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      profitAmount: profitAmount ?? this.profitAmount,
      sourceTransactionId: sourceTransactionId ?? this.sourceTransactionId,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      payments: payments ?? this.payments,
    );
  }

  /// Convert ke Map untuk database
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'buyer_name': buyerName,
      'phone_number': phoneNumber,
      'total_amount': totalAmount,
      'paid_amount': paidAmount,
      'remaining_amount': remainingAmount,
      'profit_amount': profitAmount,
      'source_transaction_id': sourceTransactionId,
      'due_date': dueDate?.toIso8601String(),
      'status': status.value,
      'notes': notes,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Convert dari Map database
  factory Receivable.fromMap(Map<String, dynamic> map) {
    return Receivable(
      id: map['id'] as int?,
      buyerName: map['buyer_name'] as String,
      phoneNumber: map['phone_number'] as String?,
      totalAmount: (map['total_amount'] as num).toDouble(),
      paidAmount: (map['paid_amount'] as num?)?.toDouble() ?? 0,
      remainingAmount: (map['remaining_amount'] as num).toDouble(),
      profitAmount: (map['profit_amount'] as num?)?.toDouble() ?? 0,
      sourceTransactionId: map['source_transaction_id'] as int?,
      dueDate: map['due_date'] != null
          ? DateTime.parse(map['due_date'] as String)
          : null,
      status: ReceivableStatus.fromValue(map['status'] as String? ?? 'pending'),
      notes: map['notes'] as String?,
      isActive: (map['is_active'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// Factory untuk membuat piutang baru
  factory Receivable.create({
    required String buyerName,
    String? phoneNumber,
    required double totalAmount,
    double profitAmount = 0,
    int? sourceTransactionId,
    DateTime? dueDate,
    String? notes,
  }) {
    final now = DateTime.now();
    return Receivable(
      buyerName: buyerName,
      phoneNumber: phoneNumber,
      totalAmount: totalAmount,
      paidAmount: 0,
      remainingAmount: totalAmount,
      profitAmount: profitAmount,
      sourceTransactionId: sourceTransactionId,
      dueDate: dueDate,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  String toString() {
    return 'Receivable(id: $id, buyer: $buyerName, total: $totalAmount, '
        'remaining: $remainingAmount, status: ${status.value})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Receivable && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Model untuk Pembayaran Piutang
class ReceivablePayment {
  final int? id;
  final int receivableId;
  final double amount;
  final String paymentMethod;
  final int? destinationAccountId;
  final String? notes;
  final DateTime paymentDate;
  final DateTime createdAt;

  // Fields untuk join
  final String? destinationAccountName;

  const ReceivablePayment({
    this.id,
    required this.receivableId,
    required this.amount,
    required this.paymentMethod,
    this.destinationAccountId,
    this.notes,
    required this.paymentDate,
    required this.createdAt,
    this.destinationAccountName,
  });

  /// Copy with
  ReceivablePayment copyWith({
    int? id,
    int? receivableId,
    double? amount,
    String? paymentMethod,
    int? destinationAccountId,
    String? notes,
    DateTime? paymentDate,
    DateTime? createdAt,
    String? destinationAccountName,
  }) {
    return ReceivablePayment(
      id: id ?? this.id,
      receivableId: receivableId ?? this.receivableId,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      destinationAccountId: destinationAccountId ?? this.destinationAccountId,
      notes: notes ?? this.notes,
      paymentDate: paymentDate ?? this.paymentDate,
      createdAt: createdAt ?? this.createdAt,
      destinationAccountName: destinationAccountName ?? this.destinationAccountName,
    );
  }

  /// Convert ke Map untuk database
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'receivable_id': receivableId,
      'amount': amount,
      'payment_method': paymentMethod,
      'destination_account_id': destinationAccountId,
      'notes': notes,
      'payment_date': paymentDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Convert dari Map database
  factory ReceivablePayment.fromMap(Map<String, dynamic> map) {
    return ReceivablePayment(
      id: map['id'] as int?,
      receivableId: map['receivable_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      paymentMethod: map['payment_method'] as String,
      destinationAccountId: map['destination_account_id'] as int?,
      notes: map['notes'] as String?,
      paymentDate: DateTime.parse(map['payment_date'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      destinationAccountName: map['destination_account_name'] as String?,
    );
  }

  @override
  String toString() {
    return 'ReceivablePayment(id: $id, receivableId: $receivableId, amount: $amount)';
  }
}

/// Enum untuk status piutang
enum ReceivableStatus {
  pending('pending', 'Belum Lunas'),
  partial('partial', 'Sebagian'),
  paid('paid', 'Lunas'),
  cancelled('cancelled', 'Dibatalkan');

  final String value;
  final String label;

  const ReceivableStatus(this.value, this.label);

  static ReceivableStatus fromValue(String value) {
    return ReceivableStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ReceivableStatus.pending,
    );
  }

  /// Warna untuk status
  String get colorHex {
    switch (this) {
      case ReceivableStatus.pending:
        return '#FFA726'; // Orange
      case ReceivableStatus.partial:
        return '#42A5F5'; // Blue
      case ReceivableStatus.paid:
        return '#66BB6A'; // Green
      case ReceivableStatus.cancelled:
        return '#EF5350'; // Red
    }
  }
}

/// Enum untuk metode pembayaran
enum PaymentMethod {
  cash('cash', 'Tunai'),
  transfer('transfer', 'Transfer'),
  digital('digital', 'E-Wallet');

  final String value;
  final String label;

  const PaymentMethod(this.value, this.label);

  static PaymentMethod fromValue(String value) {
    return PaymentMethod.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PaymentMethod.cash,
    );
  }
}

/// Extension untuk list of Receivable
extension ReceivableListExt on List<Receivable> {
  /// Total piutang belum lunas
  double get totalOutstanding {
    return where((r) => !r.isPaid && r.isActive)
        .fold(0.0, (sum, r) => sum + r.remainingAmount);
  }

  /// Total piutang yang sudah dibayar
  double get totalPaid {
    return where((r) => r.isActive).fold(0.0, (sum, r) => sum + r.paidAmount);
  }

  /// Filter piutang yang jatuh tempo
  List<Receivable> get overdueOnly {
    return where((r) => r.isOverdue && r.isActive).toList();
  }

  /// Filter piutang yang belum lunas
  List<Receivable> get unpaidOnly {
    return where((r) => !r.isPaid && r.isActive).toList();
  }

  /// Filter piutang yang sudah lunas
  List<Receivable> get paidOnly {
    return where((r) => r.isPaid && r.isActive).toList();
  }

  /// Urutkan berdasarkan jatuh tempo terdekat
  List<Receivable> get sortedByDueDate {
    final sorted = where((r) => r.isActive).toList();
    sorted.sort((a, b) {
      if (a.dueDate == null && b.dueDate == null) return 0;
      if (a.dueDate == null) return 1;
      if (b.dueDate == null) return -1;
      return a.dueDate!.compareTo(b.dueDate!);
    });
    return sorted;
  }
}
