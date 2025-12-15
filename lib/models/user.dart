class User {
  final String id;
  final String username;
  final String? email;
  final String? role;
  final String? organizationId;

  User({
    required this.id,
    required this.username,
    this.email,
    this.role = 'cashier',
    this.organizationId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'role': role,
      'organization_id': organizationId,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      username: map['username'],
      email: map['email'],
      role: map['role'] ?? 'cashier',
      organizationId: map['organization_id'] ?? map['organizationId'],
    );
  }
}