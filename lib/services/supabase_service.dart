import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../models/organization.dart';

class SupabaseService {
  final _supabase = Supabase.instance.client;

  // ========== ORGANIZATION OPERATIONS ==========

  Future<void> upsertOrganization(Organization organization) async {
    try {
      await _supabase.from('organizations').upsert({
        'id': organization.id,
        'name': organization.name,
        'owner_id': organization.ownerId,
        'address': organization.address,
        'phone': organization.phone,
        'email': organization.email,
        'tax_rate': organization.taxRate,
        'currency': organization.currency,
        'created_at': organization.createdAt.toIso8601String(),
      });
      print('Organization upserted to Supabase: ${organization.id}');
    } catch (e) {
      print('Error upserting organization to Supabase: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getOrganization(String id) async {
    try {
      final response = await _supabase
          .from('organizations')
          .select()
          .eq('id', id)
          .maybeSingle();
      return response;
    } catch (e) {
      print('Error fetching organization from Supabase: $e');
      return null;
    }
  }

  // ========== PRODUCT OPERATIONS ==========

  Future<void> upsertProduct(Product product, {String? organizationId}) async {
    try {
      await _supabase.from('products').upsert({
        'id': product.id,
        'name': product.name,
        'barcode': product.barcode,
        'price': product.price,
        'cost': product.cost,
        'stock': product.stock,
        'category': product.category,
        'image_url': product.imageUrl,  // Changed from imageUrl
        'is_active': product.isActive,  // Changed from isActive
        'organization_id': organizationId,
        'createdAt': product.createdAt.toIso8601String(),
        'created_at': product.createdAt.toIso8601String(),
      });
      print('Product upserted to Supabase: ${product.id}');
    } catch (e) {
      print('Error upserting product to Supabase: $e');
      rethrow;
    }
  }

  Future<List<Product>> getProducts({String? organizationId}) async {
    try {
      var query = _supabase.from('products').select();

      if (organizationId != null) {
        query = query.eq('organization_id', organizationId);
      }

      final response = await query;

      // Convert snake_case to camelCase
      return (response as List).map((json) {
        return Product.fromMap({
          'id': json['id'],
          'name': json['name'],
          'barcode': json['barcode'],
          'price': json['price'],
          'cost': json['cost'],
          'stock': json['stock'],
          'category': json['category'],
          'imageUrl': json['image_url'],  // Convert to camelCase
          'isActive': json['is_active'],  // Convert to camelCase
          'createdAt': json['created_at'] ?? json['createdAt'],
        });
      }).toList();
    } catch (e) {
      print('Error fetching products from Supabase: $e');
      return [];
    }
  }

  Future<void> deleteProduct(String id) async {
    try {
      await _supabase.from('products').delete().eq('id', id);
      print('Product deleted from Supabase: $id');
    } catch (e) {
      print('Error deleting product from Supabase: $e');
      rethrow;
    }
  }

  // ========== SALE OPERATIONS ==========

  Future<void> upsertSale(Sale sale, {String? organizationId}) async {
    try {
      // Insert sale
      await _supabase.from('sales').upsert({
        'id': sale.id,
        'date': sale.date.toIso8601String(),
        'subtotal': sale.subtotal,
        'discount': sale.discount,
        'tax': sale.tax,
        'total': sale.total,
        'payment_method': sale.paymentMethod,  // Changed from paymentMethod
        'amount_paid': sale.amountPaid,  // Changed from amountPaid
        'change': sale.change,
        'customer_name': sale.customerName,  // Changed from customerName
        'organization_id': organizationId,
      });

      // Insert sale items
      for (var item in sale.items) {
        await _supabase.from('sale_items').upsert({
          'id': item.id,
          'sale_id': item.saleId,  // Changed from saleId
          'product_id': item.productId,  // Changed from productId
          'product_name': item.productName,  // Changed from productName
          'price': item.price,
          'quantity': item.quantity,
          'discount': item.discount,
          'subtotal': item.subtotal,
        });
      }

      print('Sale upserted to Supabase: ${sale.id}');
    } catch (e) {
      print('Error upserting sale to Supabase: $e');
      rethrow;
    }
  }

  Future<List<Sale>> getSales({String? organizationId}) async {
    try {
      var query = _supabase.from('sales').select();

      if (organizationId != null) {
        query = query.eq('organization_id', organizationId);
      }

      final salesResponse = await query;

      List<Sale> sales = [];
      for (var saleMap in salesResponse) {
        // Get sale items
        final itemsResponse = await _supabase
            .from('sale_items')
            .select()
            .eq('sale_id', saleMap['id']);  // Changed from saleId

        // Convert to List<Map<String, dynamic>> first
        final itemsList = List<Map<String, dynamic>>.from(itemsResponse);

        // Convert snake_case to camelCase for each item
        final saleItems = itemsList.map((itemMap) {
          return SaleItem.fromMap({
            'id': itemMap['id'],
            'saleId': itemMap['sale_id'],  // Convert to camelCase
            'productId': itemMap['product_id'],  // Convert to camelCase
            'productName': itemMap['product_name'],  // Convert to camelCase
            'price': itemMap['price'],
            'quantity': itemMap['quantity'],
            'discount': itemMap['discount'],
            'subtotal': itemMap['subtotal'],
          });
        }).toList();

        // Convert sale snake_case to camelCase
        sales.add(Sale.fromMap({
          'id': saleMap['id'],
          'date': saleMap['date'],
          'subtotal': saleMap['subtotal'],
          'discount': saleMap['discount'],
          'tax': saleMap['tax'],
          'total': saleMap['total'],
          'paymentMethod': saleMap['payment_method'],  // Convert to camelCase
          'amountPaid': saleMap['amount_paid'],  // Convert to camelCase
          'change': saleMap['change'],
          'customerName': saleMap['customer_name'],  // Convert to camelCase
        }, items: saleItems));
      }

      return sales;
    } catch (e) {
      print('Error fetching sales from Supabase: $e');
      return [];
    }
  }

  // ========== USER OPERATIONS ==========

  Future<void> upsertUser(Map<String, dynamic> user) async {
    try {
      await _supabase.from('users').upsert({
        'id': user['id'],
        'username': user['username'],
        'password': user['password'],
        'email': user['email'],
        'role': user['role'],
        'organization_id': user['organization_id'],
        'created_at': user['created_at'],
      });
      print('User upserted to Supabase: ${user['id']}');
    } catch (e) {
      print('Error upserting user to Supabase: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getUsers({String? organizationId}) async {
    try {
      var query = _supabase.from('users').select();

      if (organizationId != null) {
        query = query.eq('organization_id', organizationId);
      }

      final response = await query;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching users from Supabase: $e');
      return [];
    }
  }

  // ========== EXPENSE OPERATIONS ==========

  Future<void> upsertExpense(Map<String, dynamic> expense) async {
    try {
      await _supabase.from('expenses').upsert({
        'id': expense['id'],
        'description': expense['description'],
        'amount': expense['amount'],
        'category': expense['category'],
        'date': expense['date'],
        'organization_id': expense['organization_id'],
      });
      print('Expense upserted to Supabase: ${expense['id']}');
    } catch (e) {
      print('Error upserting expense to Supabase: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getExpenses({String? organizationId}) async {
    try {
      var query = _supabase.from('expenses').select();

      if (organizationId != null) {
        query = query.eq('organization_id', organizationId);
      }

      final response = await query;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching expenses from Supabase: $e');
      return [];
    }
  }

  Future<void> deleteExpense(String id) async {
    try {
      await _supabase.from('expenses').delete().eq('id', id);
      print('Expense deleted from Supabase: $id');
    } catch (e) {
      print('Error deleting expense from Supabase: $e');
      rethrow;
    }
  }
}