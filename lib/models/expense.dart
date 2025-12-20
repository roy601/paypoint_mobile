class Expense {
  final String id;
  final String description;
  final double amount;
  final String category;
  final DateTime date;
  final String? organizationId;

  Expense({
    required this.id,
    required this.description,
    required this.amount,
    required this.category,
    required this.date,
    this.organizationId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'description': description,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
      'organization_id': organizationId,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'],
      description: map['description'],
      amount: (map['amount'] as num).toDouble(),
      category: map['category'],
      date: DateTime.parse(map['date']),
      organizationId: map['organization_id'],
    );
  }

  // Expense categories
  static const List<String> categories = [
    'Rent',
    'Electricity Bill',
    'Water Bill',
    'Salary',
    'Transportation',
    'Other',
  ];
}