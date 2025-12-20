import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/sales_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/auth_provider.dart';
import '../database/database_helper.dart';
import '../services/pdf_service.dart';
import '../models/sale.dart';
import '../models/expense.dart';

enum LedgerType {
  general,
  purchase,
  sales,
  expense,
  income,
  profitLoss,
  balanceSheet,
}

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({Key? key}) : super(key: key);

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  LedgerType _selectedLedger = LedgerType.general;
  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _singleDate;
  bool _useDateRange = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _setDefaultDates();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _setDefaultDates() {
    final now = DateTime.now();
    setState(() {
      _startDate = DateTime(now.year, now.month, 1); // First day of month
      _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      _singleDate = now;
    });
  }
  Future<double> _calculatePurchases() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final orgId = authProvider.organizationId;

    if (_useDateRange && _startDate != null && _endDate != null) {
      return await DatabaseHelper.instance.getTotalPurchasesByDateRange(
        _startDate!,
        _endDate!,
        organizationId: orgId,
      );
    } else if (!_useDateRange && _singleDate != null) {
      final startOfDay = DateTime(
        _singleDate!.year,
        _singleDate!.month,
        _singleDate!.day,
      );
      final endOfDay = startOfDay.add(const Duration(days: 1));

      return await DatabaseHelper.instance.getTotalPurchasesByDateRange(
        startOfDay,
        endOfDay,
        organizationId: orgId,
      );
    }

    return 0.0;
  }
  Future<void> _loadData() async {
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    salesProvider.setOrganizationId(authProvider.organizationId);
    expenseProvider.setOrganizationId(authProvider.organizationId);

    await salesProvider.loadSales();
    await expenseProvider.loadExpenses();
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
          23,
          59,
          59,
        );
      });
    }
  }

  Future<void> _selectSingleDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _singleDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _singleDate = picked;
      });
    }
  }

  List<Sale> _getFilteredSales(List<Sale> allSales) {
    if (_useDateRange) {
      if (_startDate == null || _endDate == null) return allSales;
      return allSales.where((s) =>
      s.date.isAfter(_startDate!) && s.date.isBefore(_endDate!)
      ).toList();
    } else {
      if (_singleDate == null) return allSales;
      final startOfDay = DateTime(
        _singleDate!.year,
        _singleDate!.month,
        _singleDate!.day,
      );
      final endOfDay = startOfDay.add(const Duration(days: 1));
      return allSales.where((s) =>
      s.date.isAfter(startOfDay) && s.date.isBefore(endOfDay)
      ).toList();
    }
  }

  List<Expense> _getFilteredExpenses(List<Expense> allExpenses) {
    if (_useDateRange) {
      if (_startDate == null || _endDate == null) return allExpenses;
      return allExpenses.where((e) =>
      e.date.isAfter(_startDate!) && e.date.isBefore(_endDate!)
      ).toList();
    } else {
      if (_singleDate == null) return allExpenses;
      final startOfDay = DateTime(
        _singleDate!.year,
        _singleDate!.month,
        _singleDate!.day,
      );
      final endOfDay = startOfDay.add(const Duration(days: 1));
      return allExpenses.where((e) =>
      e.date.isAfter(startOfDay) && e.date.isBefore(endOfDay)
      ).toList();
    }
  }

  String _getLedgerTitle() {
    switch (_selectedLedger) {
      case LedgerType.general:
        return 'General Ledger';
      case LedgerType.purchase:
        return 'Purchase Ledger';
      case LedgerType.sales:
        return 'Sales Ledger';
      case LedgerType.expense:
        return 'Expense Voucher';
      case LedgerType.income:
        return 'Income Voucher';
      case LedgerType.profitLoss:
        return 'Profit & Loss';
      case LedgerType.balanceSheet:
        return 'Balance Sheet';
    }
  }

  Future<void> _generatePDF(
      List<Sale> sales,
      List<Expense> expenses,
      ) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final orgId = authProvider.organizationId;

      String shopName = 'My Shop';
      String shopAddress = '';

      if (orgId != null) {
        final orgData = await DatabaseHelper.instance.getOrganization(orgId);
        if (orgData != null) {
          shopName = orgData['name'];
          shopAddress = orgData['address'] ?? '';
        }
      }

      final purchases = await _calculatePurchases();

      final pdfBytes = await PDFService.generateLedgerPDF(
        ledgerType: _selectedLedger,
        sales: sales,
        expenses: expenses,
        purchases: purchases, // We'll calculate this later
        startDate: _useDateRange ? _startDate! : _singleDate!,
        endDate: _useDateRange ? _endDate! : _singleDate!,
        shopName: shopName,
        shopAddress: shopAddress,
      );

      final fileName = '${_getLedgerTitle().toLowerCase().replaceAll(' ', '_')}_${DateFormat('yyyy_MM_dd').format(_useDateRange ? _startDate! : _singleDate!)}.pdf';

      await PDFService.printOrSharePDF(pdfBytes, fileName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final salesProvider = Provider.of<SalesProvider>(context);
    final expenseProvider = Provider.of<ExpenseProvider>(context);

    final filteredSales = _getFilteredSales(salesProvider.sales);
    final filteredExpenses = _getFilteredExpenses(expenseProvider.expenses);

    final currencyFormat = NumberFormat.currency(symbol: '৳', decimalDigits: 2);
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(_getLedgerTitle()),
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Icon(Icons.print),
            onPressed: _isLoading
                ? null
                : () => _generatePDF(filteredSales, filteredExpenses),
          ),
        ],
      ),
      body: Column(
        children: [
          // Ledger Type Selector
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Column(
              children: [
                DropdownButtonFormField<LedgerType>(
                  value: _selectedLedger,
                  decoration: const InputDecoration(
                    labelText: 'Ledger Type',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: LedgerType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(_getLedgerTypeLabel(type)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedLedger = value!;
                    });
                  },
                ),
                const SizedBox(height: 12),

                // Date Filter Toggle
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text('Date Range'),
                        value: true,
                        groupValue: _useDateRange,
                        onChanged: (value) {
                          setState(() {
                            _useDateRange = value!;
                          });
                        },
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text('Single Date'),
                        value: false,
                        groupValue: _useDateRange,
                        onChanged: (value) {
                          setState(() {
                            _useDateRange = value!;
                          });
                        },
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),

                // Date Selector
                if (_useDateRange)
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.date_range, color: Colors.blue),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _startDate != null && _endDate != null
                                      ? '${dateFormat.format(_startDate!)} - ${dateFormat.format(_endDate!)}'
                                      : 'Select date range',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _selectDateRange,
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: const Text('Pick'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, color: Colors.blue),
                              const SizedBox(width: 8),
                              Text(
                                _singleDate != null
                                    ? dateFormat.format(_singleDate!)
                                    : 'Select date',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _selectSingleDate,
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: const Text('Pick'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Content based on selected ledger type
          Expanded(
            child: _buildLedgerContent(
              filteredSales,
              filteredExpenses,
              currencyFormat,
              dateFormat,
            ),
          ),
        ],
      ),
    );
  }

  String _getLedgerTypeLabel(LedgerType type) {
    switch (type) {
      case LedgerType.general:
        return 'General Ledger';
      case LedgerType.purchase:
        return 'Purchase Ledger';
      case LedgerType.sales:
        return 'Sales Ledger';
      case LedgerType.expense:
        return 'Expense Voucher';
      case LedgerType.income:
        return 'Income Voucher';
      case LedgerType.profitLoss:
        return 'Profit & Loss';
      case LedgerType.balanceSheet:
        return 'Balance Sheet';
    }
  }

  Widget _buildLedgerContent(
      List<Sale> sales,
      List<Expense> expenses,
      NumberFormat currencyFormat,
      DateFormat dateFormat,
      ) {
    switch (_selectedLedger) {
      case LedgerType.general:
        return _buildGeneralLedger(sales, expenses, currencyFormat, dateFormat);
      case LedgerType.purchase:
        return _buildPurchaseLedger(currencyFormat, dateFormat);
      case LedgerType.sales:
        return _buildSalesLedger(sales, currencyFormat, dateFormat);
      case LedgerType.expense:
        return _buildExpenseLedger(expenses, currencyFormat, dateFormat);
      case LedgerType.income:
        return _buildIncomeLedger(sales, currencyFormat, dateFormat);
      case LedgerType.profitLoss:
        return _buildProfitLoss(sales, expenses, currencyFormat);
      case LedgerType.balanceSheet:
        return _buildBalanceSheet(sales, expenses, currencyFormat);
    }
  }

  Widget _buildGeneralLedger(
      List<Sale> sales,
      List<Expense> expenses,
      NumberFormat currencyFormat,
      DateFormat dateFormat,
      ) {
    // Combine all transactions
    final transactions = <Map<String, dynamic>>[];

    for (var sale in sales) {
      transactions.add({
        'type': 'Sale',
        'description': sale.customerName ?? 'Sale',
        'date': sale.date,
        'debit': 0.0,
        'credit': sale.total,
        'icon': Icons.trending_up,
        'color': Colors.green,
      });
    }

    for (var expense in expenses) {
      transactions.add({
        'type': 'Expense',
        'description': expense.description,
        'date': expense.date,
        'debit': expense.amount,
        'credit': 0.0,
        'icon': Icons.trending_down,
        'color': Colors.red,
      });
    }

    // Sort by date
    transactions.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

    final totalDebit = transactions.fold<double>(0, (sum, t) => sum + (t['debit'] as double));
    final totalCredit = transactions.fold<double>(0, (sum, t) => sum + (t['credit'] as double));

    return Column(
      children: [
        // Summary
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Card(
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text('Total Debit'),
                        const SizedBox(height: 4),
                        Text(
                          currencyFormat.format(totalDebit),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text('Total Credit'),
                        const SizedBox(height: 4),
                        Text(
                          currencyFormat.format(totalCredit),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Transactions
        Expanded(
          child: transactions.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 80,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No transactions found',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final transaction = transactions[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: transaction['color'],
                    child: Icon(
                      transaction['icon'],
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    transaction['description'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${dateFormat.format(transaction['date'])} • ${transaction['type']}',
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (transaction['debit'] > 0)
                        Text(
                          'Dr. ${currencyFormat.format(transaction['debit'])}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      if (transaction['credit'] > 0)
                        Text(
                          'Cr. ${currencyFormat.format(transaction['credit'])}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPurchaseLedger(
      NumberFormat currencyFormat,
      DateFormat dateFormat,
      ) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getPurchaseDetails(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final purchases = snapshot.data!['items'] as List<Map<String, dynamic>>;
        final total = snapshot.data!['total'] as double;

        if (purchases.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shopping_bag_outlined,
                  size: 80,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No purchases found',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add products to inventory to track purchases',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Purchases',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${purchases.length} products added',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      Text(
                        currencyFormat.format(total),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: purchases.length,
                itemBuilder: (context, index) {
                  final purchase = purchases[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.orange,
                        child: Icon(Icons.shopping_bag, color: Colors.white),
                      ),
                      title: Text(
                        purchase['name'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${dateFormat.format(purchase['date'])} • Qty: ${purchase['quantity']} @ ${currencyFormat.format(purchase['cost'])}',
                      ),
                      trailing: Text(
                        currencyFormat.format(purchase['total']),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<Map<String, dynamic>> _getPurchaseDetails() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final orgId = authProvider.organizationId;

    DateTime start, end;

    if (_useDateRange && _startDate != null && _endDate != null) {
      start = _startDate!;
      end = _endDate!;
    } else if (!_useDateRange && _singleDate != null) {
      start = DateTime(
        _singleDate!.year,
        _singleDate!.month,
        _singleDate!.day,
      );
      end = start.add(const Duration(days: 1));
    } else {
      return {'items': [], 'total': 0.0};
    }

    // Get products created in this date range
    final db = await DatabaseHelper.instance.database;

    List<Map<String, dynamic>> result;
    if (orgId != null) {
      result = await db.query(
        'products',
        where: 'createdAt >= ? AND createdAt <= ? AND organization_id = ?',
        whereArgs: [start.toIso8601String(), end.toIso8601String(), orgId],
        orderBy: 'createdAt DESC',
      );
    } else {
      result = await db.query(
        'products',
        where: 'createdAt >= ? AND createdAt <= ?',
        whereArgs: [start.toIso8601String(), end.toIso8601String()],
        orderBy: 'createdAt DESC',
      );
    }

    final purchases = result.map((p) {
      final cost = (p['cost'] as num).toDouble();
      final stock = p['stock'] as int;
      return {
        'name': p['name'],
        'date': DateTime.parse(p['createdAt'] as String),
        'cost': cost,
        'quantity': stock,
        'total': cost * stock,
      };
    }).toList();

    final total = purchases.fold<double>(0, (sum, p) => sum + (p['total'] as double));

    return {'items': purchases, 'total': total};
  }

  Widget _buildSalesLedger(
      List<Sale> sales,
      NumberFormat currencyFormat,
      DateFormat dateFormat,
      ) {
    final totalSales = sales.fold<double>(0, (sum, sale) => sum + sale.total);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Sales',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${sales.length} transactions',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  Text(
                    currencyFormat.format(totalSales),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: sales.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.point_of_sale_outlined,
                  size: 80,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No sales found',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: sales.length,
            itemBuilder: (context, index) {
              final sale = sales[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.green,
                    child: Icon(Icons.receipt, color: Colors.white),
                  ),
                  title: Text(
                    sale.customerName ?? 'Sale',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${dateFormat.format(sale.date)} • ${sale.paymentMethod}',
                  ),
                  trailing: Text(
                    currencyFormat.format(sale.total),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                      fontSize: 16,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildExpenseLedger(
      List<Expense> expenses,
      NumberFormat currencyFormat,
      DateFormat dateFormat,
      ) {
    final totalExpenses = expenses.fold<double>(0, (sum, exp) => sum + exp.amount);

    // Group by category
    final Map<String, double> categoryTotals = {};
    for (var expense in expenses) {
      categoryTotals[expense.category] =
          (categoryTotals[expense.category] ?? 0) + expense.amount;
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Expenses',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${expenses.length} entries',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  Text(
                    currencyFormat.format(totalExpenses),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (categoryTotals.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'By Category',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...categoryTotals.entries.map((entry) {
                      final percentage = (entry.value / totalExpenses) * 100;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(child: Text(entry.key)),
                            Text(
                              currencyFormat.format(entry.value),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '(${percentage.toStringAsFixed(1)}%)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        Expanded(
          child: expenses.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 80,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No expenses found',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: expenses.length,
            itemBuilder: (context, index) {
              final expense = expenses[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.red,
                    child: Icon(
                      _getExpenseCategoryIcon(expense.category),
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    expense.description,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${dateFormat.format(expense.date)} • ${expense.category}',
                  ),
                  trailing: Text(
                    currencyFormat.format(expense.amount),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                      fontSize: 16,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildIncomeLedger(
      List<Sale> sales,
      NumberFormat currencyFormat,
      DateFormat dateFormat,
      ) {
    // Same as sales ledger for now
    return _buildSalesLedger(sales, currencyFormat, dateFormat);
  }

  Widget _buildProfitLoss(
      List<Sale> sales,
      List<Expense> expenses,
      NumberFormat currencyFormat,
      ) {
    return FutureBuilder<double>(
      future: _calculatePurchases(),
      builder: (context, snapshot) {
        final purchases = snapshot.data ?? 0.0;
        final totalRevenue = sales.fold<double>(0, (sum, sale) => sum + sale.total);
        final totalExpenses = expenses.fold<double>(0, (sum, exp) => sum + exp.amount);
        final totalCost = totalExpenses + purchases;
        final profit = totalRevenue - totalCost;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Revenue',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      title: const Text('Sales'),
                      trailing: Text(
                        currencyFormat.format(totalRevenue),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      title: const Text(
                        'Total Revenue',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: Text(
                        currencyFormat.format(totalRevenue),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Expenses',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      title: const Text('Operating Expenses'),
                      trailing: Text(
                        currencyFormat.format(totalExpenses),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ),
                    ListTile(
                      title: const Text('Purchases'),
                      trailing: Text(
                        currencyFormat.format(purchases),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      title: const Text(
                        'Total Expenses',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: Text(
                        currencyFormat.format(totalCost),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: profit >= 0 ? Colors.green.shade100 : Colors.red.shade100,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      profit >= 0 ? 'Net Profit' : 'Net Loss',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currencyFormat.format(profit.abs()),
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: profit >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${currencyFormat.format(totalRevenue)} - ${currencyFormat.format(totalCost)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBalanceSheet(
      List<Sale> sales,
      List<Expense> expenses,
      NumberFormat currencyFormat,
      ) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return FutureBuilder<double>(
      future: authProvider.organizationId != null
          ? DatabaseHelper.instance.getOpeningBalance(authProvider.organizationId!)
          : Future.value(0.0),
      builder: (context, snapshot) {
        final cash = snapshot.data ?? 0.0;
        final totalRevenue = sales.fold<double>(0, (sum, sale) => sum + sale.total);
        final totalExpenses = expenses.fold<double>(0, (sum, exp) => sum + exp.amount);

        final totalAssets = cash + totalRevenue;
        final totalLiabilities = totalExpenses;
        final equity = totalAssets - totalLiabilities;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Assets',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      title: const Text('Cash'),
                      trailing: Text(
                        currencyFormat.format(cash),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    ListTile(
                      title: const Text('Accounts Receivable'),
                      trailing: Text(
                        currencyFormat.format(totalRevenue),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      title: const Text(
                        'Total Assets',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: Text(
                        currencyFormat.format(totalAssets),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Liabilities',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      title: const Text('Accounts Payable'),
                      trailing: Text(
                        currencyFormat.format(totalLiabilities),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      title: const Text(
                        'Total Liabilities',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: Text(
                        currencyFormat.format(totalLiabilities),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Equity',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      title: const Text('Owner\'s Equity'),
                      trailing: Text(
                        currencyFormat.format(equity),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      title: const Text(
                        'Total Equity',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: Text(
                        currencyFormat.format(equity),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: Colors.grey.shade200,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ListTile(
                  title: const Text(
                    'Balance Check',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Assets = Liabilities + Equity',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  trailing: Icon(
                    totalAssets == (totalLiabilities + equity)
                        ? Icons.check_circle
                        : Icons.error,
                    color: totalAssets == (totalLiabilities + equity)
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  IconData _getExpenseCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'rent':
        return Icons.home;
      case 'electricity bill':
        return Icons.flash_on;
      case 'water bill':
        return Icons.water_drop;
      case 'salary':
        return Icons.people;
      case 'transportation':
        return Icons.local_shipping;
      default:
        return Icons.receipt;
    }
  }
}