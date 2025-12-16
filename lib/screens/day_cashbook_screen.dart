import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/sales_provider.dart';
import '../providers/auth_provider.dart';
import '../database/database_helper.dart';
import '../services/pdf_service.dart';
import '../models/sale.dart';

class DayCashbookScreen extends StatefulWidget {
  const DayCashbookScreen({Key? key}) : super(key: key);

  @override
  State<DayCashbookScreen> createState() => _DayCashbookScreenState();
}

class _DayCashbookScreenState extends State<DayCashbookScreen> {
  DateTime _selectedDate = DateTime.now();
  double _openingBalance = 0.0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    salesProvider.setOrganizationId(authProvider.organizationId);
    await salesProvider.loadSales();
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

      final pdfBytes = await PDFService.generateDayCashbookPDF(
        sales: sales,
        date: _selectedDate,
        shopName: shopName,
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
    final daySales = _getDaySales(salesProvider.sales);
    final cashSales = daySales.where((s) => s.paymentMethod == 'Cash').toList();

    final currencyFormat = NumberFormat.currency(symbol: '৳', decimalDigits: 2);
    final dateFormat = DateFormat('dd MMM yyyy');
    final timeFormat = DateFormat('hh:mm a');

    final totalCashIn = cashSales.fold<double>(0, (sum, sale) => sum + sale.total);
    final closingBalance = _openingBalance + totalCashIn;

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
            onPressed: _isLoading || cashSales.isEmpty
                ? null
                : () => _generatePDF(cashSales),
          ),
        ],
      ),
      body: Column(
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
              child: ListTile(
                leading: const Icon(Icons.account_balance_wallet, color: Colors.blue),
                title: const Text('Opening Balance'),
                trailing: SizedBox(
                  width: 120,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      prefixText: '৳ ',
                    ),
                    onChanged: (value) {
                      setState(() {
                        _openingBalance = double.tryParse(value) ?? 0.0;
                      });
                    },
                  ),
                ),
              ),
            ),
          ),

          // Cash Transactions
          Expanded(
            child: salesProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : cashSales.isEmpty
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
                    'No cash transactions',
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
              itemCount: cashSales.length,
              itemBuilder: (context, index) {
                final sale = cashSales[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green,
                      child: const Icon(
                        Icons.arrow_downward,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      sale.customerName ?? 'Cash Sale',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(timeFormat.format(sale.date)),
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

          // Summary
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
                    const Text('Total Cash In:'),
                    Text(
                      currencyFormat.format(totalCashIn),
                      style: const TextStyle(fontWeight: FontWeight.bold),
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
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}