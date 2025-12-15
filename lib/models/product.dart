class Product {
  final String id;
  final String name;
  final String? barcode;
  final double price;
  final double cost;
  final int stock;
  final String? category;
  final String? imageUrl;
  final bool isActive;
  final DateTime createdAt;

  Product({
    required this.id,
    required this.name,
    this.barcode,
    required this.price,
    required this.cost,
    required this.stock,
    this.category,
    this.imageUrl,
    this.isActive = true,
    required this.createdAt,
  });

  // Convert to Map for database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'barcode': barcode,
      'price': price,
      'cost': cost,
      'stock': stock,
      'category': category,
      'imageUrl': imageUrl,
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Create from Map
  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      name: map['name'],
      barcode: map['barcode'],
      price: map['price'],
      cost: map['cost'],
      stock: map['stock'],
      category: map['category'],
      imageUrl: map['imageUrl'],
      isActive: map['isActive'] == 1,
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  // Copy with method for updates
  Product copyWith({
    String? id,
    String? name,
    String? barcode,
    double? price,
    double? cost,
    int? stock,
    String? category,
    String? imageUrl,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      stock: stock ?? this.stock,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}