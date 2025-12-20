import 'package:flutter/foundation.dart';
import '../models/expense.dart';
import '../database/database_helper.dart';
import '../services/supabase_service.dart';

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
  Future<List<Expense>> getExpensesByDateRange(DateTime start,
      DateTime end) async {
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

      // ✅ ADD THIS: Auto-sync to Supabase
      _syncExpenseToSupabase(expense);
    }

    return error;
  }

// Update expense
  Future<void> updateExpense(Expense expense) async {
    await DatabaseHelper.instance.updateExpense(expense.toMap());
    await loadExpenses();

    // ✅ ADD THIS: Auto-sync to Supabase
    _syncExpenseToSupabase(expense);
  }

// Delete expense
  Future<void> deleteExpense(String id) async {
    await DatabaseHelper.instance.deleteExpense(id);
    await loadExpenses();

    // ✅ ADD THIS: Auto-sync deletion to Supabase
    _syncExpenseDeletionToSupabase(id);
  }

// ✅ ADD THESE HELPER METHODS:
  void _syncExpenseToSupabase(Expense expense) async {
    try {
      final supabaseService = SupabaseService();
      await supabaseService.upsertExpense(expense.toMap());
      print('Expense synced to Supabase: ${expense.id}');
    } catch (e) {
      print('Failed to sync expense to Supabase: $e');
      // Don't throw - allow offline operation
    }
  }

  void _syncExpenseDeletionToSupabase(String id) async {
    try {
      final supabaseService = SupabaseService();
      await supabaseService.deleteExpense(id);
      print('Expense deletion synced to Supabase: $id');
    } catch (e) {
      print('Failed to sync expense deletion to Supabase: $e');
      // Don't throw - allow offline operation
    }
  }
}