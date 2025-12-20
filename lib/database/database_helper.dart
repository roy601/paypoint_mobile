import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('paypoint.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4,  // Updated to version 4
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const intType = 'INTEGER NOT NULL';
    const realType = 'REAL NOT NULL';
    const boolType = 'INTEGER NOT NULL';

    // Organizations table with opening balance
    await db.execute('''
      CREATE TABLE organizations (
        id $idType,
        name $textType,
        owner_id $textType,
        address TEXT,
        phone TEXT,
        email TEXT,
        tax_rate REAL DEFAULT 0,
        currency TEXT DEFAULT 'BDT',
        opening_balance REAL DEFAULT 0,
        is_opening_balance_set INTEGER DEFAULT 0,
        created_at $textType
      )
    ''');

    // Users table
    await db.execute('''
      CREATE TABLE users (
        id $idType,
        username $textType UNIQUE,
        password $textType,
        email TEXT,
        role $textType,
        organization_id TEXT,
        created_at $textType,
        FOREIGN KEY (organization_id) REFERENCES organizations (id)
      )
    ''');

    // Products table
    await db.execute('''
      CREATE TABLE products (
        id $idType,
        name $textType,
        barcode TEXT,
        price $realType,
        cost $realType,
        stock $intType,
        category TEXT,
        imageUrl TEXT,
        isActive $boolType,
        organization_id TEXT,
        createdAt $textType,
        FOREIGN KEY (organization_id) REFERENCES organizations (id)
      )
    ''');

    // Sales table
    await db.execute('''
      CREATE TABLE sales (
        id $idType,
        date $textType,
        subtotal $realType,
        discount $realType,
        tax $realType,
        total $realType,
        paymentMethod $textType,
        amountPaid $realType,
        change $realType,
        customerName TEXT,
        organization_id TEXT,
        FOREIGN KEY (organization_id) REFERENCES organizations (id)
      )
    ''');

    // Sale Items table
    await db.execute('''
      CREATE TABLE sale_items (
        id $idType,
        saleId $textType,
        productId $textType,
        productName $textType,
        price $realType,
        quantity $intType,
        discount $realType,
        subtotal $realType,
        FOREIGN KEY (saleId) REFERENCES sales (id) ON DELETE CASCADE
      )
    ''');

    // Expenses table
    await db.execute('''
      CREATE TABLE expenses (
        id $idType,
        description $textType,
        amount $realType,
        category $textType,
        date $textType,
        organization_id TEXT,
        FOREIGN KEY (organization_id) REFERENCES organizations (id)
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add users table if upgrading from version 1
      const idType = 'TEXT PRIMARY KEY';
      const textType = 'TEXT NOT NULL';

      await db.execute('''
        CREATE TABLE IF NOT EXISTS users (
          id $idType,
          username $textType UNIQUE,
          password $textType,
          email TEXT,
          role $textType,
          createdAt $textType
        )
      ''');
    }

    if (oldVersion < 3) {
      // Add organizations table
      const idType = 'TEXT PRIMARY KEY';
      const textType = 'TEXT NOT NULL';

      await db.execute('''
        CREATE TABLE IF NOT EXISTS organizations (
          id $idType,
          name $textType,
          owner_id $textType,
          address TEXT,
          phone TEXT,
          email TEXT,
          tax_rate REAL DEFAULT 0,
          currency TEXT DEFAULT 'BDT',
          created_at $textType
        )
      ''');

      // Add organization_id column to existing tables
      await db.execute('ALTER TABLE users ADD COLUMN organization_id TEXT');
      await db.execute('ALTER TABLE products ADD COLUMN organization_id TEXT');
      await db.execute('ALTER TABLE sales ADD COLUMN organization_id TEXT');
    }

    if (oldVersion < 4) {
      // Add expenses table
      const idType = 'TEXT PRIMARY KEY';
      const textType = 'TEXT NOT NULL';
      const realType = 'REAL NOT NULL';

      await db.execute('''
        CREATE TABLE IF NOT EXISTS expenses (
          id $idType,
          description $textType,
          amount $realType,
          category $textType,
          date $textType,
          organization_id TEXT
        )
      ''');

      // Add opening balance columns to organizations
      await db.execute('''
        ALTER TABLE organizations 
        ADD COLUMN opening_balance REAL DEFAULT 0
      ''');

      await db.execute('''
        ALTER TABLE organizations 
        ADD COLUMN is_opening_balance_set INTEGER DEFAULT 0
      ''');
    }
  }

  // ========== ORGANIZATION OPERATIONS ==========

  Future<Map<String, dynamic>> createOrganization({
    required String id,
    required String name,
    required String ownerId,
    String? address,
    String? phone,
    String? email,
    double taxRate = 0.0,
    String currency = 'BDT',
  }) async {
    final db = await database;

    try {
      await db.insert('organizations', {
        'id': id,
        'name': name,
        'owner_id': ownerId,
        'address': address,
        'phone': phone,
        'email': email,
        'tax_rate': taxRate,
        'currency': currency,
        'opening_balance': 0.0,
        'is_opening_balance_set': 0,
        'created_at': DateTime.now().toIso8601String(),
      });
      return {
        'success': true,
        'organization_id': id,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error creating organization: $e',
      };
    }
  }

  Future<Map<String, dynamic>?> getOrganization(String id) async {
    final db = await database;
    final result = await db.query(
      'organizations',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getAllOrganizations() async {
    final db = await database;
    return await db.query('organizations', orderBy: 'created_at DESC');
  }

  Future<Map<String, dynamic>?> getOrganizationByOwnerId(String ownerId) async {
    final db = await database;
    final result = await db.query(
      'organizations',
      where: 'owner_id = ?',
      whereArgs: [ownerId],
    );

    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  Future<int> updateOrganization(Map<String, dynamic> organization) async {
    final db = await database;
    return db.update(
      'organizations',
      organization,
      where: 'id = ?',
      whereArgs: [organization['id']],
    );
  }

  // ========== ORGANIZATION OPENING BALANCE ==========

  Future<bool> setOpeningBalance(String organizationId, double amount) async {
    final db = await database;

    try {
      // Check if already set
      final org = await getOrganization(organizationId);
      if (org != null && org['is_opening_balance_set'] == 1) {
        return false; // Already set, cannot change
      }

      // Set opening balance
      await db.update(
        'organizations',
        {
          'opening_balance': amount,
          'is_opening_balance_set': 1,
        },
        where: 'id = ?',
        whereArgs: [organizationId],
      );

      return true;
    } catch (e) {
      print('Error setting opening balance: $e');
      return false;
    }
  }

  Future<double> getOpeningBalance(String organizationId) async {
    final org = await getOrganization(organizationId);
    return (org?['opening_balance'] as num?)?.toDouble() ?? 0.0;
  }

  Future<bool> isOpeningBalanceSet(String organizationId) async {
    final org = await getOrganization(organizationId);
    return (org?['is_opening_balance_set'] as int?) == 1;
  }

  // ========== USER OPERATIONS ==========

  Future<String?> createUser(
      String id,
      String username,
      String password, {
        String? email,
        String role = 'cashier',
        String? organizationId,
      }) async {
    final db = await database;

    try {
      await db.insert('users', {
        'id': id,
        'username': username,
        'password': password,
        'email': email,
        'role': role,
        'organization_id': organizationId,
        'created_at': DateTime.now().toIso8601String(),
      });
      return null; // Success
    } catch (e) {
      if (e.toString().contains('UNIQUE constraint failed')) {
        return 'Username already exists';
      }
      return 'Error creating user';
    }
  }

  Future<Map<String, dynamic>?> getUserByUsername(String username) async {
    final db = await database;
    final result = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
    );

    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  Future<bool> validateUser(String username, String password) async {
    final user = await getUserByUsername(username);
    if (user == null) return false;

    return user['password'] == password;
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final db = await database;
    return await db.query('users', orderBy: 'created_at DESC');
  }

  Future<List<Map<String, dynamic>>> getUsersByOrganization(String organizationId) async {
    final db = await database;
    return await db.query(
      'users',
      where: 'organization_id = ?',
      whereArgs: [organizationId],
      orderBy: 'created_at DESC',
    );
  }

  Future<int> deleteUser(String id) async {
    final db = await database;
    return await db.delete(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ========== PRODUCT OPERATIONS ==========

  Future<Product> createProduct(Product product, {String? organizationId}) async {
    final db = await database;
    final productMap = product.toMap();
    productMap['organization_id'] = organizationId;
    await db.insert('products', productMap);
    return product;
  }

  Future<List<Product>> getAllProducts({String? organizationId}) async {
    final db = await database;
    List<Map<String, dynamic>> result;

    if (organizationId != null) {
      result = await db.query(
        'products',
        where: 'organization_id = ?',
        whereArgs: [organizationId],
        orderBy: 'name ASC',
      );
    } else {
      result = await db.query('products', orderBy: 'name ASC');
    }

    return result.map((json) => Product.fromMap(json)).toList();
  }

  Future<Product?> getProduct(String id) async {
    final db = await database;
    final maps = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Product.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateProduct(Product product, {String? organizationId}) async {
    final db = await database;
    final productMap = product.toMap();
    if (organizationId != null) {
      productMap['organization_id'] = organizationId;
    }
    return db.update(
      'products',
      productMap,
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<int> deleteProduct(String id) async {
    final db = await database;
    return await db.delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Product>> searchProducts(String query, {String? organizationId}) async {
    final db = await database;
    List<Map<String, dynamic>> result;

    if (organizationId != null) {
      result = await db.query(
        'products',
        where: '(name LIKE ? OR barcode LIKE ?) AND organization_id = ?',
        whereArgs: ['%$query%', '%$query%', organizationId],
      );
    } else {
      result = await db.query(
        'products',
        where: 'name LIKE ? OR barcode LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
      );
    }

    return result.map((json) => Product.fromMap(json)).toList();
  }

  Future<List<Product>> getActiveProducts({String? organizationId}) async {
    final db = await database;
    List<Map<String, dynamic>> result;

    if (organizationId != null) {
      result = await db.query(
        'products',
        where: 'isActive = ? AND organization_id = ?',
        whereArgs: [1, organizationId],
        orderBy: 'name ASC',
      );
    } else {
      result = await db.query(
        'products',
        where: 'isActive = ?',
        whereArgs: [1],
        orderBy: 'name ASC',
      );
    }

    return result.map((json) => Product.fromMap(json)).toList();
  }

  Future<List<Product>> getProductsByCategory(String category, {String? organizationId}) async {
    final db = await database;
    List<Map<String, dynamic>> result;

    if (organizationId != null) {
      result = await db.query(
        'products',
        where: 'category = ? AND isActive = ? AND organization_id = ?',
        whereArgs: [category, 1, organizationId],
        orderBy: 'name ASC',
      );
    } else {
      result = await db.query(
        'products',
        where: 'category = ? AND isActive = ?',
        whereArgs: [category, 1],
        orderBy: 'name ASC',
      );
    }

    return result.map((json) => Product.fromMap(json)).toList();
  }

  // ========== SALE OPERATIONS ==========

  Future<Sale> createSale(Sale sale, {String? organizationId}) async {
    final db = await database;

    await db.transaction((txn) async {
      // Insert sale
      final saleMap = sale.toMap();
      saleMap['organization_id'] = organizationId;
      await txn.insert('sales', saleMap);

      // Insert sale items
      for (var item in sale.items) {
        await txn.insert('sale_items', item.toMap());
      }

      // Update product stock
      for (var item in sale.items) {
        await txn.rawUpdate(
          'UPDATE products SET stock = stock - ? WHERE id = ?',
          [item.quantity, item.productId],
        );
      }
    });

    return sale;
  }

  Future<List<Sale>> getAllSales({String? organizationId}) async {
    final db = await database;
    List<Map<String, dynamic>> salesResult;

    if (organizationId != null) {
      salesResult = await db.query(
        'sales',
        where: 'organization_id = ?',
        whereArgs: [organizationId],
        orderBy: 'date DESC',
      );
    } else {
      salesResult = await db.query('sales', orderBy: 'date DESC');
    }

    List<Sale> sales = [];
    for (var saleMap in salesResult) {
      final items = await getSaleItems(saleMap['id'] as String);
      sales.add(Sale.fromMap(saleMap, items: items));
    }

    return sales;
  }

  Future<List<SaleItem>> getSaleItems(String saleId) async {
    final db = await database;
    final result = await db.query(
      'sale_items',
      where: 'saleId = ?',
      whereArgs: [saleId],
    );
    return result.map((json) => SaleItem.fromMap(json)).toList();
  }

  Future<Sale?> getSale(String id) async {
    final db = await database;
    final maps = await db.query(
      'sales',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      final items = await getSaleItems(id);
      return Sale.fromMap(maps.first, items: items);
    }
    return null;
  }

  Future<List<Sale>> getSalesByDate(DateTime date, {String? organizationId}) async {
    final db = await database;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    List<Map<String, dynamic>> salesResult;

    if (organizationId != null) {
      salesResult = await db.query(
        'sales',
        where: 'date >= ? AND date < ? AND organization_id = ?',
        whereArgs: [
          startOfDay.toIso8601String(),
          endOfDay.toIso8601String(),
          organizationId,
        ],
        orderBy: 'date DESC',
      );
    } else {
      salesResult = await db.query(
        'sales',
        where: 'date >= ? AND date < ?',
        whereArgs: [
          startOfDay.toIso8601String(),
          endOfDay.toIso8601String(),
        ],
        orderBy: 'date DESC',
      );
    }

    List<Sale> sales = [];
    for (var saleMap in salesResult) {
      final items = await getSaleItems(saleMap['id'] as String);
      sales.add(Sale.fromMap(saleMap, items: items));
    }

    return sales;
  }

  Future<List<Sale>> getSalesByDateRange(DateTime start, DateTime end, {String? organizationId}) async {
    final db = await database;

    List<Map<String, dynamic>> salesResult;

    if (organizationId != null) {
      salesResult = await db.query(
        'sales',
        where: 'date >= ? AND date <= ? AND organization_id = ?',
        whereArgs: [
          start.toIso8601String(),
          end.toIso8601String(),
          organizationId,
        ],
        orderBy: 'date DESC',
      );
    } else {
      salesResult = await db.query(
        'sales',
        where: 'date >= ? AND date <= ?',
        whereArgs: [
          start.toIso8601String(),
          end.toIso8601String(),
        ],
        orderBy: 'date DESC',
      );
    }

    List<Sale> sales = [];
    for (var saleMap in salesResult) {
      final items = await getSaleItems(saleMap['id'] as String);
      sales.add(Sale.fromMap(saleMap, items: items));
    }

    return sales;
  }

  Future<double> getTodayTotalSales({String? organizationId}) async {
    final db = await database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    List<Map<String, dynamic>> result;

    if (organizationId != null) {
      result = await db.rawQuery(
        'SELECT SUM(total) as total FROM sales WHERE date >= ? AND date < ? AND organization_id = ?',
        [startOfDay.toIso8601String(), endOfDay.toIso8601String(), organizationId],
      );
    } else {
      result = await db.rawQuery(
        'SELECT SUM(total) as total FROM sales WHERE date >= ? AND date < ?',
        [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      );
    }

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<int> getTodaySalesCount({String? organizationId}) async {
    final db = await database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    List<Map<String, dynamic>> result;

    if (organizationId != null) {
      result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM sales WHERE date >= ? AND date < ? AND organization_id = ?',
        [startOfDay.toIso8601String(), endOfDay.toIso8601String(), organizationId],
      );
    } else {
      result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM sales WHERE date >= ? AND date < ?',
        [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      );
    }

    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ========== EXPENSE OPERATIONS ==========

  Future<String?> createExpense({
    required String id,
    required String description,
    required double amount,
    required String category,
    required DateTime date,
    String? organizationId,
  }) async {
    final db = await database;

    try {
      await db.insert('expenses', {
        'id': id,
        'description': description,
        'amount': amount,
        'category': category,
        'date': date.toIso8601String(),
        'organization_id': organizationId,
      });
      return null; // Success
    } catch (e) {
      return 'Error creating expense: $e';
    }
  }

  Future<List<Map<String, dynamic>>> getAllExpenses({String? organizationId}) async {
    final db = await database;

    if (organizationId != null) {
      return await db.query(
        'expenses',
        where: 'organization_id = ?',
        whereArgs: [organizationId],
        orderBy: 'date DESC',
      );
    } else {
      return await db.query('expenses', orderBy: 'date DESC');
    }
  }

  Future<List<Map<String, dynamic>>> getExpensesByDate(
      DateTime date,
      {String? organizationId}
      ) async {
    final db = await database;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    if (organizationId != null) {
      return await db.query(
        'expenses',
        where: 'date >= ? AND date < ? AND organization_id = ?',
        whereArgs: [
          startOfDay.toIso8601String(),
          endOfDay.toIso8601String(),
          organizationId,
        ],
        orderBy: 'date DESC',
      );
    } else {
      return await db.query(
        'expenses',
        where: 'date >= ? AND date < ?',
        whereArgs: [
          startOfDay.toIso8601String(),
          endOfDay.toIso8601String(),
        ],
        orderBy: 'date DESC',
      );
    }
  }

  Future<List<Map<String, dynamic>>> getExpensesByDateRange(
      DateTime start,
      DateTime end,
      {String? organizationId}
      ) async {
    final db = await database;

    if (organizationId != null) {
      return await db.query(
        'expenses',
        where: 'date >= ? AND date <= ? AND organization_id = ?',
        whereArgs: [
          start.toIso8601String(),
          end.toIso8601String(),
          organizationId,
        ],
        orderBy: 'date DESC',
      );
    } else {
      return await db.query(
        'expenses',
        where: 'date >= ? AND date <= ?',
        whereArgs: [
          start.toIso8601String(),
          end.toIso8601String(),
        ],
        orderBy: 'date DESC',
      );
    }
  }

  Future<int> updateExpense(Map<String, dynamic> expense) async {
    final db = await database;
    return db.update(
      'expenses',
      expense,
      where: 'id = ?',
      whereArgs: [expense['id']],
    );
  }

  Future<int> deleteExpense(String id) async {
    final db = await database;
    return await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<double> getTotalExpensesByDateRange(
      DateTime start,
      DateTime end,
      {String? organizationId}
      ) async {
    final db = await database;

    List<Map<String, dynamic>> result;

    if (organizationId != null) {
      result = await db.rawQuery(
        'SELECT SUM(amount) as total FROM expenses WHERE date >= ? AND date <= ? AND organization_id = ?',
        [start.toIso8601String(), end.toIso8601String(), organizationId],
      );
    } else {
      result = await db.rawQuery(
        'SELECT SUM(amount) as total FROM expenses WHERE date >= ? AND date <= ?',
        [start.toIso8601String(), end.toIso8601String()],
      );
    }

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  // ========== PURCHASE TRACKING (using product cost) ==========

  Future<double> getTotalPurchasesByDateRange(
      DateTime start,
      DateTime end,
      {String? organizationId}
      ) async {
    final db = await database;

    // Get all products created in this date range
    List<Map<String, dynamic>> result;

    if (organizationId != null) {
      result = await db.rawQuery(
        'SELECT SUM(cost * stock) as total FROM products WHERE createdAt >= ? AND createdAt <= ? AND organization_id = ?',
        [start.toIso8601String(), end.toIso8601String(), organizationId],
      );
    } else {
      result = await db.rawQuery(
        'SELECT SUM(cost * stock) as total FROM products WHERE createdAt >= ? AND createdAt <= ?',
        [start.toIso8601String(), end.toIso8601String()],
      );
    }

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  // ========== UTILITY OPERATIONS ==========

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('sale_items');
    await db.delete('sales');
    await db.delete('products');
    await db.delete('expenses');
    // Don't delete users and organizations tables
  }

  Future close() async {
    final db = await database;
    db.close();
  }
}