import '../database/database_helper.dart';
import 'supabase_service.dart';
import 'connectivity_service.dart';
import '../models/organization.dart';

class SyncService {
  final SupabaseService _supabaseService = SupabaseService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Check if device is online
  Future<bool> isOnline() async {
    return await _connectivityService.isOnline();
  }

  // Sync all data (products, sales, users, organizations)
  Future<Map<String, dynamic>> syncAll({String? organizationId}) async {
    final online = await isOnline();
    if (!online) {
      return {
        'success': false,
        'message': 'No internet connection',
      };
    }

    try {
      // ✅ Sync ALL organizations first (not just one)
      await syncAllOrganizations();

      // Sync products
      await syncProducts(organizationId: organizationId);

      // Sync sales
      await syncSales(organizationId: organizationId);

      // Sync users
      await syncUsers(organizationId: organizationId);

      return {
        'success': true,
        'message': 'All data synced successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Sync failed: $e',
      };
    }
  }
// Sync expenses (bidirectional)
  Future<void> syncExpenses({String? organizationId}) async {
    try {
      // 1. Push local expenses to Supabase
      List<Map<String, dynamic>> localExpenses;

      if (organizationId != null) {
        localExpenses = await _dbHelper.getExpensesByDateRange(
          DateTime(2020, 1, 1),
          DateTime.now(),
          organizationId: organizationId,
        );
      } else {
        localExpenses = await _dbHelper.getAllExpenses();
      }

      for (var expense in localExpenses) {
        await _supabaseService.upsertExpense(expense);
      }

      // 2. Pull expenses from Supabase to local
      final remoteExpenses = await _supabaseService.getExpenses(
        organizationId: organizationId,
      );

      for (var expense in remoteExpenses) {
        // Check if expense exists locally
        final existingExpenses = await _dbHelper.getAllExpenses(
          organizationId: organizationId,
        );

        final exists = existingExpenses.any((e) => e['id'] == expense['id']);

        if (!exists) {
          // Create expense locally
          await _dbHelper.createExpense(
            id: expense['id'],
            description: expense['description'],
            amount: (expense['amount'] as num).toDouble(),
            category: expense['category'],
            date: DateTime.parse(expense['date']),
            organizationId: expense['organization_id'],
          );
        } else {
          // Update existing expense
          await _dbHelper.updateExpense(expense);
        }
      }

      print('Expenses synced successfully');
    } catch (e) {
      print('Error syncing expenses: $e');
      rethrow;
    }
  }
  // ✅ NEW: Sync ALL organizations from local DB
  Future<void> syncAllOrganizations() async {
    try {
      // Get all organizations from local database
      final allOrgs = await _dbHelper.getAllOrganizations();

      if (allOrgs.isEmpty) {
        print('No organizations to sync');
        return;
      }

      for (var orgMap in allOrgs) {
        final organization = Organization.fromMap(orgMap);
        await _supabaseService.upsertOrganization(organization);
        print('Synced organization: ${organization.name}');
      }

      print('All organizations synced successfully');
    } catch (e) {
      print('Error syncing all organizations: $e');
      rethrow;
    }
  }

  // Sync single organization (for backward compatibility)
  Future<void> syncOrganization(String organizationId) async {
    try {
      // Get local organization
      final localOrg = await _dbHelper.getOrganization(organizationId);

      if (localOrg != null) {
        final organization = Organization.fromMap(localOrg);
        await _supabaseService.upsertOrganization(organization);
      }

      print('Organization synced successfully');
    } catch (e) {
      print('Error syncing organization: $e');
      rethrow;
    }
  }

  // Sync products (bidirectional)
  Future<void> syncProducts({String? organizationId}) async {
    try {
      // 1. Push local products to Supabase
      final localProducts = await _dbHelper.getAllProducts(
        organizationId: organizationId,
      );
      for (var product in localProducts) {
        await _supabaseService.upsertProduct(
          product,
          organizationId: organizationId,
        );
      }

      // 2. Pull products from Supabase to local
      final remoteProducts = await _supabaseService.getProducts(
        organizationId: organizationId,
      );
      for (var product in remoteProducts) {
        final existingProduct = await _dbHelper.getProduct(product.id);
        if (existingProduct == null) {
          await _dbHelper.createProduct(
            product,
            organizationId: organizationId,
          );
        } else {
          await _dbHelper.updateProduct(
            product,
            organizationId: organizationId,
          );
        }
      }

      print('Products synced successfully');
    } catch (e) {
      print('Error syncing products: $e');
      rethrow;
    }
  }

  // Sync sales (push only - local to Supabase)
  Future<void> syncSales({String? organizationId}) async {
    try {
      // Push local sales to Supabase
      final localSales = await _dbHelper.getAllSales(
        organizationId: organizationId,
      );
      for (var sale in localSales) {
        await _supabaseService.upsertSale(
          sale,
          organizationId: organizationId,
        );
      }

      print('Sales synced successfully');
    } catch (e) {
      print('Error syncing sales: $e');
      rethrow;
    }
  }

  // Sync users (bidirectional)
  Future<void> syncUsers({String? organizationId}) async {
    try {
      // 1. Push local users to Supabase
      List<Map<String, dynamic>> localUsers;

      if (organizationId != null) {
        localUsers = await _dbHelper.getUsersByOrganization(organizationId);
      } else {
        localUsers = await _dbHelper.getAllUsers();
      }

      for (var user in localUsers) {
        await _supabaseService.upsertUser(user);
      }

      // 2. Pull users from Supabase to local
      final remoteUsers = await _supabaseService.getUsers(
        organizationId: organizationId,
      );
      for (var user in remoteUsers) {
        final existingUser = await _dbHelper.getUserByUsername(user['username']);
        if (existingUser == null) {
          await _dbHelper.createUser(
            user['id'],
            user['username'],
            user['password'],
            email: user['email'],
            role: user['role'] ?? 'cashier',
            organizationId: user['organization_id'],
          );
        }
      }

      print('Users synced successfully');
    } catch (e) {
      print('Error syncing users: $e');
      rethrow;
    }
  }

  // Auto-sync on app start
  Future<void> autoSync({String? organizationId}) async {
    final online = await isOnline();
    if (online) {
      print('Auto-syncing data...');
      await syncAll(organizationId: organizationId);
    } else {
      print('Offline - skipping auto-sync');
    }
  }
}