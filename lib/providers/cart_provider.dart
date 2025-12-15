import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import 'package:uuid/uuid.dart';

class CartItem {
  final Product product;
  int quantity;
  double discount;

  CartItem({
    required this.product,
    this.quantity = 1,
    this.discount = 0.0,
  });

  double get subtotal => (product.price * quantity) - discount;
}

class CartProvider with ChangeNotifier {
  final Map<String, CartItem> _items = {};
  double _cartDiscount = 0.0;
  double _taxRate = 0.0; // percentage (e.g., 5 for 5%)

  Map<String, CartItem> get items => {..._items};

  int get itemCount => _items.length;

  int get totalQuantity {
    return _items.values.fold(0, (sum, item) => sum + item.quantity);
  }

  double get subtotal {
    return _items.values.fold(0.0, (sum, item) => sum + item.subtotal);
  }

  double get discount => _cartDiscount;

  double get tax {
    final taxableAmount = subtotal - _cartDiscount;
    return taxableAmount * (_taxRate / 100);
  }

  double get total {
    return subtotal - _cartDiscount + tax;
  }

  bool get isEmpty => _items.isEmpty;

  void addItem(Product product, {int quantity = 1}) {
    if (_items.containsKey(product.id)) {
      _items[product.id]!.quantity += quantity;
    } else {
      _items[product.id] = CartItem(product: product, quantity: quantity);
    }
    notifyListeners();
  }

  void removeItem(String productId) {
    _items.remove(productId);
    notifyListeners();
  }

  void updateQuantity(String productId, int quantity) {
    if (_items.containsKey(productId)) {
      if (quantity <= 0) {
        _items.remove(productId);
      } else {
        _items[productId]!.quantity = quantity;
      }
      notifyListeners();
    }
  }

  void updateItemDiscount(String productId, double discount) {
    if (_items.containsKey(productId)) {
      _items[productId]!.discount = discount;
      notifyListeners();
    }
  }

  void setCartDiscount(double discount) {
    _cartDiscount = discount;
    notifyListeners();
  }

  void setTaxRate(double rate) {
    _taxRate = rate;
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _cartDiscount = 0.0;
    notifyListeners();
  }

  Sale createSale({
    required String paymentMethod,
    required double amountPaid,
    String? customerName,
  }) {
    final uuid = Uuid();
    final saleId = uuid.v4();

    final saleItems = _items.values.map((cartItem) {
      return SaleItem(
        id: uuid.v4(),
        saleId: saleId,
        productId: cartItem.product.id,
        productName: cartItem.product.name,
        price: cartItem.product.price,
        quantity: cartItem.quantity,
        discount: cartItem.discount,
        subtotal: cartItem.subtotal,
      );
    }).toList();

    final sale = Sale(
      id: saleId,
      date: DateTime.now(),
      subtotal: subtotal,
      discount: _cartDiscount,
      tax: tax,
      total: total,
      paymentMethod: paymentMethod,
      amountPaid: amountPaid,
      change: amountPaid - total,
      customerName: customerName,
      items: saleItems,
    );

    return sale;
  }
}