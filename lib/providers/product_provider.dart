import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../database/database_helper.dart';

class ProductProvider with ChangeNotifier {
  List<Product> _products = [];
  bool _isLoading = false;
  String? _organizationId;

  List<Product> get products => [..._products];
  List<Product> get activeProducts =>
      _products.where((p) => p.isActive).toList();

  bool get isLoading => _isLoading;

  void setOrganizationId(String? orgId) {
    _organizationId = orgId;
  }

  Future<void> loadProducts() async {
    _isLoading = true;
    notifyListeners();

    try {
      _products = await DatabaseHelper.instance.getAllProducts(
        organizationId: _organizationId,
      );
    } catch (e) {
      print('Error loading products: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addProduct(Product product) async {
    try {
      await DatabaseHelper.instance.createProduct(
        product,
        organizationId: _organizationId,
      );
      _products.add(product);
      notifyListeners();
    } catch (e) {
      print('Error adding product: $e');
      rethrow;
    }
  }

  Future<void> updateProduct(Product product) async {
    try {
      await DatabaseHelper.instance.updateProduct(
        product,
        organizationId: _organizationId,
      );
      final index = _products.indexWhere((p) => p.id == product.id);
      if (index != -1) {
        _products[index] = product;
        notifyListeners();
      }
    } catch (e) {
      print('Error updating product: $e');
      rethrow;
    }
  }

  Future<void> deleteProduct(String id) async {
    try {
      await DatabaseHelper.instance.deleteProduct(id);
      _products.removeWhere((p) => p.id == id);
      notifyListeners();
    } catch (e) {
      print('Error deleting product: $e');
      rethrow;
    }
  }

  Future<List<Product>> searchProducts(String query) async {
    if (query.isEmpty) return activeProducts;
    return await DatabaseHelper.instance.searchProducts(
      query,
      organizationId: _organizationId,
    );
  }

  Product? getProductById(String id) {
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }
}