class Organization {
  final String id;
  final String name;
  final String ownerId;
  final String? address;
  final String? phone;
  final String? email;
  final double taxRate;
  final String currency;
  final DateTime createdAt;

  Organization({
    required this.id,
    required this.name,
    required this.ownerId,
    this.address,
    this.phone,
    this.email,
    this.taxRate = 0.0,
    this.currency = 'BDT',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'owner_id': ownerId,
      'address': address,
      'phone': phone,
      'email': email,
      'tax_rate': taxRate,
      'currency': currency,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Organization.fromMap(Map<String, dynamic> map) {
    return Organization(
      id: map['id'],
      name: map['name'],
      ownerId: map['owner_id'] ?? map['ownerId'],
      address: map['address'],
      phone: map['phone'],
      email: map['email'],
      taxRate: (map['tax_rate'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] ?? 'BDT',
      createdAt: DateTime.parse(map['created_at'] ?? map['createdAt']),
    );
  }
}