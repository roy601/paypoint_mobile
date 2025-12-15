class SaleItem {
  final String id;
  final String saleId;
  final String productId;
  final String productName;
  final double price;
  final int quantity;
  final double discount;
  final double subtotal;

  SaleItem({
    required this.id,
    required this.saleId,
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    this.discount = 0.0,
    required this.subtotal,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'saleId': saleId,
      'productId': productId,
      'productName': productName,
      'price': price,
      'quantity': quantity,
      'discount': discount,
      'subtotal': subtotal,
    };
  }

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      id: map['id'],
      saleId: map['saleId'],
      productId: map['productId'],
      productName: map['productName'],
      price: map['price'],
      quantity: map['quantity'],
      discount: map['discount'] ?? 0.0,
      subtotal: map['subtotal'],
    );
  }
}