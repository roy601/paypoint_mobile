import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../models/organization.dart';

class SupabaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ========== ORGANIZATIONS ==========

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
    } catch (e) {
      print('Error upserting organization to Supabase: $e');
      rethrow;
    }
  }

  Future<Organization?> getOrganization(String id) async {
    try {
      final response = await _supabase
          .from('organizations')
          .select()
          .eq('id', id)
          .single();

      return Organization.fromMap(response);
    } catch (e) {
      print('Error fetching organization from Supabase: $e');
      return null;
    }
  }

  // ========== PRODUCTS ==========

  Future<List<Product>> getProducts({String? organizationId}) async {
    try {
      var query = _supabase.from('products').select();

      if (organizationId != null) {
        query = query.eq('organization_id', organizationId);
      }

      final response = await query.order('name', ascending: true);

      return (response as List).map((json) {
        return Product(
          id: json['id'],
          name: json['name'],
          barcode: json['barcode'],
          price: (json['price'] as num).toDouble(),
          cost: (json['cost'] as num).toDouble(),
          stock: json['stock'] as int,
          category: json['category'],
          imageUrl: json['image_url'],
          isActive: json['is_active'] ?? true,
          createdAt: DateTime.parse(json['created_at']),
        );
      }).toList();
    } catch (e) {
      print('Error fetching products from Supabase: $e');
      return [];
    }
  }

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
        'image_url': product.imageUrl,
        'is_active': product.isActive,
        'organization_id': organizationId,
        'created_at': product.createdAt.toIso8601String(),
        'synced_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error upserting product to Supabase: $e');
      rethrow;
    }
  }

  Future<void> deleteProduct(String id) async {
    try {
      await _supabase.from('products').delete().eq('id', id);
    } catch (e) {
      print('Error deleting product from Supabase: $e');
      rethrow;
    }
  }

  // ========== SALES ==========

  Future<List<Sale>> getSales({String? organizationId}) async {
    try {
      var query = _supabase.from('sales').select('*, sale_items(*)');

      if (organizationId != null) {
        query = query.eq('organization_id', organizationId);
      }

      final response = await query.order('date', ascending: false);

      return (response as List).map((json) {
        final items = (json['sale_items'] as List).map((itemJson) {
          return SaleItem(
            id: itemJson['id'],
            saleId: itemJson['sale_id'],
            productId: itemJson['product_id'],
            productName: itemJson['product_name'],
            price: (itemJson['price'] as num).toDouble(),
            quantity: itemJson['quantity'] as int,
            discount: (itemJson['discount'] as num?)?.toDouble() ?? 0.0,
            subtotal: (itemJson['subtotal'] as num).toDouble(),
          );
        }).toList();

        return Sale(
          id: json['id'],
          date: DateTime.parse(json['date']),
          subtotal: (json['subtotal'] as num).toDouble(),
          discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
          tax: (json['tax'] as num?)?.toDouble() ?? 0.0,
          total: (json['total'] as num).toDouble(),
          paymentMethod: json['payment_method'],
          amountPaid: (json['amount_paid'] as num).toDouble(),
          change: (json['change'] as num?)?.toDouble() ?? 0.0,
          customerName: json['customer_name'],
          items: items,
        );
      }).toList();
    } catch (e) {
      print('Error fetching sales from Supabase: $e');
      return [];
    }
  }

  Future<void> upsertSale(Sale sale, {String? organizationId}) async {
    try {
      // Insert/update sale
      await _supabase.from('sales').upsert({
        'id': sale.id,
        'date': sale.date.toIso8601String(),
        'subtotal': sale.subtotal,
        'discount': sale.discount,
        'tax': sale.tax,
        'total': sale.total,
        'payment_method': sale.paymentMethod,
        'amount_paid': sale.amountPaid,
        'change': sale.change,
        'customer_name': sale.customerName,
        'organization_id': organizationId,
        'synced_at': DateTime.now().toIso8601String(),
      });

      // Delete existing sale items
      await _supabase.from('sale_items').delete().eq('sale_id', sale.id);

      // Insert sale items
      for (var item in sale.items) {
        await _supabase.from('sale_items').insert({
          'id': item.id,
          'sale_id': item.saleId,
          'product_id': item.productId,
          'product_name': item.productName,
          'price': item.price,
          'quantity': item.quantity,
          'discount': item.discount,
          'subtotal': item.subtotal,
        });
      }
    } catch (e) {
      print('Error upserting sale to Supabase: $e');
      rethrow;
    }
  }

  // ========== USERS ==========

  Future<void> upsertUser(Map<String, dynamic> user) async {
    try {
      await _supabase.from('users').upsert({
        'id': user['id'],
        'username': user['username'],
        'password': user['password'],
        'email': user['email'],
        'role': user['role'],
        'organization_id': user['organization_id'],
        'created_at': user['created_at'] ?? user['createdAt'],
        'synced_at': DateTime.now().toIso8601String(),
      });
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

      final response = await query.order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching users from Supabase: $e');
      return [];
    }
  }
}