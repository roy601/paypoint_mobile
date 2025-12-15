import 'package:flutter/foundation.dart';
import '../models/sale.dart';
import '../database/database_helper.dart';

class SalesProvider with ChangeNotifier {
  List<Sale> _sales = [];
  bool _isLoading = false;
  String? _organizationId;

  List<Sale> get sales => [..._sales];
  bool get isLoading => _isLoading;

  void setOrganizationId(String? orgId) {
    _organizationId = orgId;
  }

  Future<void> loadSales() async {
    _isLoading = true;
    notifyListeners();

    try {
      _sales = await DatabaseHelper.instance.getAllSales(
        organizationId: _organizationId,
      );
    } catch (e) {
      print('Error loading sales: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addSale(Sale sale) async {
    try {
      await DatabaseHelper.instance.createSale(
        sale,
        organizationId: _organizationId,
      );
      _sales.insert(0, sale);
      notifyListeners();
    } catch (e) {
      print('Error adding sale: $e');
      rethrow;
    }
  }

  Future<double> getTodayTotal() async {
    try {
      return await DatabaseHelper.instance.getTodayTotalSales(
        organizationId: _organizationId,
      );
    } catch (e) {
      print('Error getting today total: $e');
      return 0.0;
    }
  }

  Future<int> getTodayCount() async {
    try {
      return await DatabaseHelper.instance.getTodaySalesCount(
        organizationId: _organizationId,
      );
    } catch (e) {
      print('Error getting today count: $e');
      return 0;
    }
  }

  Future<List<Sale>> getSalesByDateRange(DateTime start, DateTime end) async {
    try {
      return await DatabaseHelper.instance.getSalesByDateRange(
        start,
        end,
        organizationId: _organizationId,
      );
    } catch (e) {
      print('Error getting sales by date range: $e');
      return [];
    }
  }
}