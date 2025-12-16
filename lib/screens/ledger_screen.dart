import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/sales_provider.dart';
import '../providers/auth_provider.dart';
import '../database/database_helper.dart';
import '../services/pdf_service.dart';
import '../models/sale.dart';

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({Key? key}) : super(key: key);

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
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
    });
  }

  Future<void> _loadData() async {
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    salesProvider.setOrganizationId(authProvider.organizationId);
    await salesProvider.loadSales();
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

  List<Sale> _getFilteredSales(List<Sale> allSales) {
    if (_startDate == null || _endDate == null) {
      return allSales;
    }

    return allSales.where((s) =>
    s.date.isAfter(_startDate!) && s.date.isBefore(_endDate!)
    ).toList();
  }

  Future<void> _generatePDF(List<Sale> sales) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final orgId = authProvider.organizationId;

      String shopName = 'My Shop';
      if (orgId != null) {
        final orgData = await DatabaseHelper.instance.getOrganization(orgId);
        if (orgData != null) {
          shopName = orgData['name'];
        }
      }

      final pdfBytes = await PDFService.generateLedgerPDF(
        sales: sales,
        startDate: _startDate!,
        endDate: _endDate!,
        shopName: shopName,
      );

      await PDFService.printOrSharePDF(
        pdfBytes,
        'ledger_${DateFormat('yyyy_MM_dd').format(_startDate!)}_to_${DateFormat('yyyy_MM_dd').format(_endDate!)}.pdf',
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
    final filteredSales = _getFilteredSales(salesProvider.sales);

    final currencyFormat = NumberFormat.currency(symbol: '৳', decimalDigits: 2);
    final dateFormat = DateFormat('MMM dd, yyyy');

    final totalRevenue = filteredSales.fold<double>(0, (sum, sale) => sum + sale.total);
    final totalSales = filteredSales.length;

    // Payment method breakdown
    final Map<String, double> paymentBreakdown = {};
    for (var sale in filteredSales) {
      paymentBreakdown[sale.paymentMethod] =
          (paymentBreakdown[sale.paymentMethod] ?? 0) + sale.total;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Ledger'),
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
            onPressed: _isLoading || filteredSales.isEmpty
                ? null
                : () => _generatePDF(filteredSales),
          ),
        ],
      ),
      body: Column(
        children: [
          // Date Range Selector
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Column(
              children: [
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
                ),
              ],
            ),
          ),

          // Summary Cards
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Icon(Icons.receipt_long,
                              color: Colors.blue, size: 32),
                          const SizedBox(height: 8),
                          Text(
                            '$totalSales',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const Text('Total Sales'),
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
                          const Icon(Icons.attach_money,
                              color: Colors.green, size: 32),
                          const SizedBox(height: 8),
                          Text(
                            currencyFormat.format(totalRevenue),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const Text('Revenue'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Payment Methods Breakdown
          if (paymentBreakdown.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payment Methods',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...paymentBreakdown.entries.map((entry) {
                        final percentage = (entry.value / totalRevenue) * 100;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(entry.key),
                              ),
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

          // Transactions List
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Transactions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$totalSales entries',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: salesProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredSales.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
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
              itemCount: filteredSales.length,
              itemBuilder: (context, index) {
                final sale = filteredSales[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getPaymentColor(sale.paymentMethod),
                      child: Icon(
                        _getPaymentIcon(sale.paymentMethod),
                        color: Colors.white,
                        size: 20,
                      ),
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
      ),
    );
  }

  Color _getPaymentColor(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return Colors.green;
      case 'card':
        return Colors.blue;
      case 'mobile banking':
        return Colors.orange;
      default:
        return Colors.purple;
    }
  }

  IconData _getPaymentIcon(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return Icons.payments;
      case 'card':
        return Icons.credit_card;
      case 'mobile banking':
        return Icons.phone_android;
      default:
        return Icons.account_balance_wallet;
    }
  }
}