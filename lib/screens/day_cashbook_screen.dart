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

class DayCashbookScreen extends StatefulWidget {
  const DayCashbookScreen({Key? key}) : super(key: key);

  @override
  State<DayCashbookScreen> createState() => _DayCashbookScreenState();
}

class _DayCashbookScreenState extends State<DayCashbookScreen> {
  DateTime _selectedDate = DateTime.now();
  double _openingBalance = 0.0;
  bool _isOpeningBalanceSet = false;
  bool _isLoading = false;
  final _openingBalanceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _openingBalanceController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final orgId = authProvider.organizationId;

    salesProvider.setOrganizationId(orgId);
    expenseProvider.setOrganizationId(orgId);

    await salesProvider.loadSales();
    await expenseProvider.loadExpenses();

    // Load opening balance
    if (orgId != null) {
      final balance = await DatabaseHelper.instance.getOpeningBalance(orgId);
      final isSet = await DatabaseHelper.instance.isOpeningBalanceSet(orgId);

      setState(() {
        _openingBalance = balance;
        _isOpeningBalanceSet = isSet;
        _openingBalanceController.text = balance.toString();
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _setOpeningBalance() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final orgId = authProvider.organizationId;

    if (orgId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Organization not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final amount = double.tryParse(_openingBalanceController.text) ?? 0.0;

    if (amount < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Opening balance cannot be negative'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final success = await DatabaseHelper.instance.setOpeningBalance(orgId, amount);

    if (success) {
      setState(() {
        _openingBalance = amount;
        _isOpeningBalanceSet = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening balance set successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening balance already set and cannot be changed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Sale> _getDaySales(List<Sale> allSales) {
    final startOfDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return allSales.where((sale) =>
    sale.date.isAfter(startOfDay) && sale.date.isBefore(endOfDay)
    ).toList();
  }

  List<Expense> _getDayExpenses(List<Expense> allExpenses) {
    final startOfDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return allExpenses.where((expense) =>
    expense.date.isAfter(startOfDay) && expense.date.isBefore(endOfDay)
    ).toList();
  }

  Future<void> _generatePDF(
      List<Sale> sales,
      List<Expense> expenses,
      double purchases,
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

      final pdfBytes = await PDFService.generateDayCashbookPDF(
        sales: sales,
        expenses: expenses,
        purchases: purchases,
        date: _selectedDate,
        shopName: shopName,
        shopAddress: shopAddress,
        openingBalance: _openingBalance,
      );

      await PDFService.printOrSharePDF(
        pdfBytes,
        'day_cashbook_${DateFormat('yyyy_MM_dd').format(_selectedDate)}.pdf',
      );
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

    final daySales = _getDaySales(salesProvider.sales);
    final dayExpenses = _getDayExpenses(expenseProvider.expenses);

    final currencyFormat = NumberFormat.currency(symbol: '৳', decimalDigits: 2);
    final dateFormat = DateFormat('dd MMM yyyy');
    final timeFormat = DateFormat('hh:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Day Cashbook'),
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
            onPressed: null, // Will enable after FutureBuilder
          ),
        ],
      ),
      body: FutureBuilder<double>(
        future: _calculateDayPurchases(_selectedDate),
        builder: (context, snapshot) {
          final totalPurchases = snapshot.data ?? 0.0;

          // Calculate totals
          final totalSales = daySales.fold<double>(0, (sum, sale) => sum + sale.total);
          final totalExpenses = dayExpenses.fold<double>(0, (sum, exp) => sum + exp.amount);

          final totalCreditIn = totalSales;
          final totalDebitOut = totalExpenses + totalPurchases;
          final closingBalance = _openingBalance + totalCreditIn - totalDebitOut;

          return Column(
            children: [
              // Date Selector
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.blue.shade50,
                child: Row(
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
                              dateFormat.format(_selectedDate),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _selectDate,
                      icon: const Icon(Icons.edit_calendar, size: 18),
                      label: const Text('Change'),
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
              ),

              // Opening Balance
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.account_balance_wallet, color: Colors.blue),
                            const SizedBox(width: 8),
                            const Text(
                              'Opening Balance',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _openingBalanceController,
                                keyboardType: TextInputType.number,
                                enabled: !_isOpeningBalanceSet,
                                decoration: InputDecoration(
                                  border: const OutlineInputBorder(),
                                  prefixText: '৳ ',
                                  filled: true,
                                  fillColor: _isOpeningBalanceSet
                                      ? Colors.grey[200]
                                      : Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (!_isOpeningBalanceSet)
                              ElevatedButton(
                                onPressed: _setOpeningBalance,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                ),
                                child: const Text('Set'),
                              ),
                          ],
                        ),
                        if (_isOpeningBalanceSet)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                Icon(Icons.lock, size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  'Opening balance is locked',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // Transactions Tabs
              Expanded(
                child: DefaultTabController(
                  length: 3,
                  child: Column(
                    children: [
                      const TabBar(
                        labelColor: Colors.blue,
                        unselectedLabelColor: Colors.grey,
                        tabs: [
                          Tab(text: 'Credit (In)'),
                          Tab(text: 'Debit (Out)'),
                          Tab(text: 'Summary'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            // Credit Tab (Sales)
                            _buildCreditTab(daySales, currencyFormat, timeFormat),

                            // Debit Tab (Expenses + Purchases)
                            _buildDebitTab(dayExpenses, totalPurchases, currencyFormat, timeFormat),

                            // Summary Tab
                            _buildSummaryTab(
                              totalSales,
                              totalExpenses,
                              totalPurchases,
                              closingBalance,
                              currencyFormat,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  border: Border(
                    top: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Credit (In):'),
                        Text(
                          currencyFormat.format(totalCreditIn),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Debit (Out):'),
                        Text(
                          currencyFormat.format(totalDebitOut),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Closing Balance:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          currencyFormat.format(closingBalance),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: closingBalance >= 0 ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<double> _calculateDayPurchases(DateTime date) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final orgId = authProvider.organizationId;

    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return await DatabaseHelper.instance.getTotalPurchasesByDateRange(
      startOfDay,
      endOfDay,
      organizationId: orgId,
    );
  }

  Widget _buildCreditTab(
      List<Sale> sales,
      NumberFormat currencyFormat,
      DateFormat timeFormat,
      ) {
    if (sales.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.arrow_downward,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No credit transactions',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sales.length,
      itemBuilder: (context, index) {
        final sale = sales[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.green,
              child: Icon(
                Icons.arrow_downward,
                color: Colors.white,
              ),
            ),
            title: Text(
              sale.customerName ?? 'Sale',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${timeFormat.format(sale.date)} • ${sale.paymentMethod}',
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
    );
  }

  Widget _buildDebitTab(
      List<Expense> expenses,
      double purchases,
      NumberFormat currencyFormat,
      DateFormat timeFormat,
      ) {
    if (expenses.isEmpty && purchases == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.arrow_upward,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No debit transactions',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: expenses.length + (purchases > 0 ? 1 : 0),
      itemBuilder: (context, index) {
        // Show purchases first
        if (purchases > 0 && index == 0) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.orange,
                child: Icon(
                  Icons.shopping_bag,
                  color: Colors.white,
                ),
              ),
              title: const Text(
                'Purchases',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Product stock purchases'),
              trailing: Text(
                currencyFormat.format(purchases),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                  fontSize: 16,
                ),
              ),
            ),
          );
        }

        // Adjust index for expenses
        final expenseIndex = purchases > 0 ? index - 1 : index;
        final expense = expenses[expenseIndex];

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
              '${timeFormat.format(expense.date)} • ${expense.category}',
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
    );
  }

  Widget _buildSummaryTab(
      double sales,
      double expenses,
      double purchases,
      double closing,
      NumberFormat currencyFormat,
      ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Opening Balance',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  currencyFormat.format(_openingBalance),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Credit (Money In)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.trending_up, color: Colors.green),
            title: const Text('Sales'),
            trailing: Text(
              currencyFormat.format(sales),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Debit (Money Out)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.shopping_bag, color: Colors.orange),
            title: const Text('Purchases'),
            trailing: Text(
              currencyFormat.format(purchases),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.receipt_long, color: Colors.red),
            title: const Text('Expenses'),
            trailing: Text(
              currencyFormat.format(expenses),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          color: closing >= 0 ? Colors.green.shade50 : Colors.red.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Closing Balance',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  currencyFormat.format(closing),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: closing >= 0 ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${currencyFormat.format(_openingBalance)} + ${currencyFormat.format(sales)} - ${currencyFormat.format(purchases + expenses)}',
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