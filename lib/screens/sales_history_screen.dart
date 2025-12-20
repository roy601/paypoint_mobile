import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/sales_provider.dart';
import '../providers/auth_provider.dart';
import '../models/sale.dart';
import 'sale_detail_screen.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({Key? key}) : super(key: key);

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isFiltered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSales();
    });
  }

  void _loadSales() {
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    salesProvider.setOrganizationId(authProvider.organizationId);
    salesProvider.loadSales();
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _isFiltered = true;
      });
      _filterSales();
    }
  }

  Future<void> _filterSales() async {
    if (_startDate != null && _endDate != null) {
      final salesProvider = Provider.of<SalesProvider>(context, listen: false);
      final filteredSales = await salesProvider.getSalesByDateRange(
        _startDate!,
        _endDate!.add(const Duration(days: 1)),
      );
      // Update the UI with filtered sales
      setState(() {});
    }
  }

  void _clearFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _isFiltered = false;
    });
    _loadSales();
  }

  @override
  Widget build(BuildContext context) {
    final salesProvider = Provider.of<SalesProvider>(context);
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
        actions: [
          IconButton(
            icon: Icon(_isFiltered ? Icons.filter_alt : Icons.filter_alt_outlined),
            onPressed: _selectDateRange,
          ),
          if (_isFiltered)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearFilter,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSales,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Info
          if (_isFiltered)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.blue.shade50,
              child: Row(
                children: [
                  const Icon(Icons.date_range, size: 20, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    'Filtered: ${dateFormat.format(_startDate!)} - ${dateFormat.format(_endDate!)}',
                    style: const TextStyle(color: Colors.blue),
                  ),
                ],
              ),
            ),

          // Sales Summary Card
          FutureBuilder<Map<String, dynamic>>(
            future: _getSalesSummary(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final summary = snapshot.data!;
                return _buildSummaryCard(summary);
              }
              return const SizedBox.shrink();
            },
          ),

          // Sales List
          Expanded(
            child: salesProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : salesProvider.sales.isEmpty
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
                    'No sales yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: salesProvider.sales.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final sale = salesProvider.sales[index];
                return _buildSaleCard(sale);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(Map<String, dynamic> summary) {
    final currencyFormat = NumberFormat.currency(symbol: '৳', decimalDigits: 2);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildSummaryItem(
              'Total Sales',
              '${summary['count']}',
              Icons.receipt,
              Colors.blue,
            ),
            Container(
              width: 1,
              height: 40,
              color: Colors.grey[300],
            ),
            _buildSummaryItem(
              'Revenue',
              currencyFormat.format(summary['total']),
              Icons.attach_money,
              Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Future<Map<String, dynamic>> _getSalesSummary() async {
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    final sales = salesProvider.sales;

    final total = sales.fold<double>(0, (sum, sale) => sum + sale.total);

    return {
      'count': sales.length,
      'total': total,
    };
  }

  Widget _buildSaleCard(Sale sale) {
    final currencyFormat = NumberFormat.currency(symbol: '৳', decimalDigits: 2);
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green,
          child: Text(
            '${sale.items.length}',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              currencyFormat.format(sale.total),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getPaymentMethodColor(sale.paymentMethod).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                sale.paymentMethod,
                style: TextStyle(
                  fontSize: 12,
                  color: _getPaymentMethodColor(sale.paymentMethod),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${dateFormat.format(sale.date)} at ${timeFormat.format(sale.date)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            if (sale.customerName != null)
              Text(
                'Customer: ${sale.customerName}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            Text(
              '${sale.items.length} item(s)',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SaleDetailScreen(sale: sale),
            ),
          );
        },
        isThreeLine: true,
      ),
    );
  }

  Color _getPaymentMethodColor(String method) {
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
}