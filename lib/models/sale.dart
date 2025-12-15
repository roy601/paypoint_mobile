import 'sale_item.dart';

class Sale {
  final String id;
  final DateTime date;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final String paymentMethod;
  final double amountPaid;
  final double change;
  final String? customerName;
  final List<SaleItem> items;

  Sale({
    required this.id,
    required this.date,
    required this.subtotal,
    this.discount = 0.0,
    this.tax = 0.0,
    required this.total,
    required this.paymentMethod,
    required this.amountPaid,
    this.change = 0.0,
    this.customerName,
    this.items = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'subtotal': subtotal,
      'discount': discount,
      'tax': tax,
      'total': total,
      'paymentMethod': paymentMethod,
      'amountPaid': amountPaid,
      'change': change,
      'customerName': customerName,
    };
  }

  factory Sale.fromMap(Map<String, dynamic> map, {List<SaleItem>? items}) {
    return Sale(
      id: map['id'],
      date: DateTime.parse(map['date']),
      subtotal: map['subtotal'],
      discount: map['discount'] ?? 0.0,
      tax: map['tax'] ?? 0.0,
      total: map['total'],
      paymentMethod: map['paymentMethod'],
      amountPaid: map['amountPaid'],
      change: map['change'] ?? 0.0,
      customerName: map['customerName'],
      items: items ?? [],
    );
  }

  Sale copyWith({
    String? id,
    DateTime? date,
    double? subtotal,
    double? discount,
    double? tax,
    double? total,
    String? paymentMethod,
    double? amountPaid,
    double? change,
    String? customerName,
    List<SaleItem>? items,
  }) {
    return Sale(
      id: id ?? this.id,
      date: date ?? this.date,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      total: total ?? this.total,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      amountPaid: amountPaid ?? this.amountPaid,
      change: change ?? this.change,
      customerName: customerName ?? this.customerName,
      items: items ?? this.items,
    );
  }
}