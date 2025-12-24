class JournalEntry {
  final String id;
  final String transactionId;
  final String accountId;
  final int debit;
  final int credit;

  JournalEntry({
    required this.id,
    required this.transactionId,
    required this.accountId,
    required this.debit,
    required this.credit,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'transaction_id': transactionId,
        'account_id': accountId,
        'debit': debit,
        'credit': credit,
      };
}
