import 'package:flutter/foundation.dart';
import '../models/expense.dart';
import '../database/database_helper.dart';

class ExpenseProvider with ChangeNotifier {
  List<Expense> _expenses = [];
  bool _isLoading = false;
  String? _organizationId;

  List<Expense> get expenses => _expenses;
  bool get isLoading => _isLoading;

  void setOrganizationId(String? orgId) {
    _organizationId = orgId;
  }

  // Load all expenses
  Future<void> loadExpenses() async {
    _isLoading = true;
    notifyListeners();

    try {
      final expensesMaps = await DatabaseHelper.instance.getAllExpenses(
        organizationId: _organizationId,
      );

      _expenses = expensesMaps.map((map) => Expense.fromMap(map)).toList();
    } catch (e) {
      print('Error loading expenses: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get expenses by date
  Future<List<Expense>> getExpensesByDate(DateTime date) async {
    try {
      final expensesMaps = await DatabaseHelper.instance.getExpensesByDate(
        date,
        organizationId: _organizationId,
      );

      return expensesMaps.map((map) => Expense.fromMap(map)).toList();
    } catch (e) {
      print('Error getting expenses by date: $e');
      return [];
    }
  }

  // Get expenses by date range
  Future<List<Expense>> getExpensesByDateRange(DateTime start, DateTime end) async {
    try {
      final expensesMaps = await DatabaseHelper.instance.getExpensesByDateRange(
        start,
        end,
        organizationId: _organizationId,
      );

      return expensesMaps.map((map) => Expense.fromMap(map)).toList();
    } catch (e) {
      print('Error getting expenses by date range: $e');
      return [];
    }
  }

  // Create expense
  Future<String?> createExpense(Expense expense) async {
    final error = await DatabaseHelper.instance.createExpense(
      id: expense.id,
      description: expense.description,
      amount: expense.amount,
      category: expense.category,
      date: expense.date,
      organizationId: _organizationId,
    );

    if (error == null) {
      await loadExpenses();
    }

    return error;
  }

  // Update expense
  Future<void> updateExpense(Expense expense) async {
    await DatabaseHelper.instance.updateExpense(expense.toMap());
    await loadExpenses();
  }

  // Delete expense
  Future<void> deleteExpense(String id) async {
    await DatabaseHelper.instance.deleteExpense(id);
    await loadExpenses();
  }

  // Get total expenses for date range
  Future<double> getTotalExpensesByDateRange(DateTime start, DateTime end) async {
    return await DatabaseHelper.instance.getTotalExpensesByDateRange(
      start,
      end,
      organizationId: _organizationId,
    );
  }
}