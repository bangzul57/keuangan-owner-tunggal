class Account {
  final String id;
  final String name;
  final String type;
  final String subType;
  final bool isActive;

  Account({
    required this.id,
    required this.name,
    required this.type,
    required this.subType,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type,
        'sub_type': subType,
        'is_active': isActive ? 1 : 0,
      };
}
