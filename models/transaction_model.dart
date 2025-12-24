class TransactionModel {
  final String id;
  final int date;
  final String description;
  final String category;
  final bool isReversed;

  TransactionModel({
    required this.id,
    required this.date,
    required this.description,
    required this.category,
    this.isReversed = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date,
        'description': description,
        'category': category,
        'is_reversed': isReversed ? 1 : 0,
      };
}
