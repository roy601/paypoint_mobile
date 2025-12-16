import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/sales_provider.dart';
import '../providers/product_provider.dart';
import '../providers/auth_provider.dart';
import '../database/database_helper.dart';
import '../services/pdf_service.dart';
import '../models/sale.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedPeriod = 'Today';
  final List<String> _periods = ['Today', 'This Week', 'This Month', 'Custom'];
  bool _isGeneratingPDF = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _setInitialDates();
    });
  }

  void _setInitialDates() {
    final now = DateTime.now();
    setState(() {
      _startDate = DateTime(now.year, now.month, now.day);
      _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    });
  }

  void _loadData() {
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    salesProvider.setOrganizationId(authProvider.organizationId);
    productProvider.setOrganizationId(authProvider.organizationId);

    salesProvider.loadSales();
    productProvider.loadProducts();
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
        _selectedPeriod = 'Custom';
      });
    }
  }

  void _setPeriod(String period) {
    final now = DateTime.now();

    setState(() {
      _selectedPeriod = period;

      switch (period) {
        case 'Today':
          _startDate = DateTime(now.year, now.month, now.day);
          _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;

        case 'This Week':
          final weekStart = now.subtract(Duration(days: now.weekday - 1));
          _startDate = DateTime(weekStart.year, weekStart.month, weekStart.day);
          _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;

        case 'This Month':
          _startDate = DateTime(now.year, now.month, 1);
          _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
      }
    });
  }

  List<Sale> _getFilteredSales(List<Sale> allSales) {
    if (_startDate == null || _endDate == null) {
      return allSales;
    }

    return allSales.where((s) =>
    s.date.isAfter(_startDate!) && s.date.isBefore(_endDate!)
    ).toList();
  }

  Future<void> _generatePDF() async {
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    final filteredSales = _getFilteredSales(salesProvider.sales);

    if (filteredSales.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No sales data to export'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isGeneratingPDF = true;
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

      // Calculate stats
      final totalSales = filteredSales.length;
      final totalRevenue = filteredSales.fold<double>(0, (sum, sale) => sum + sale.total);
      final avgOrderValue = totalSales > 0 ? totalRevenue / totalSales : 0.0;
      final totalItems = filteredSales.fold<int>(
        0,
            (sum, sale) => sum + sale.items.fold<int>(
          0,
              (itemSum, item) => itemSum + item.quantity,
        ),
      );

      // Top products
      final Map<String, Map<String, dynamic>> productSales = {};
      for (var sale in filteredSales) {
        for (var item in sale.items) {
          if (productSales.containsKey(item.productId)) {
            productSales[item.productId]!['quantity'] += item.quantity;
            productSales[item.productId]!['revenue'] += item.subtotal;
          } else {
            productSales[item.productId] = {
              'name': item.productName,
              'quantity': item.quantity,
              'revenue': item.subtotal,
            };
          }
        }
      }

      final sortedProducts = productSales.entries.toList()
        ..sort((a, b) => b.value['quantity'].compareTo(a.value['quantity']));

      final topProducts = sortedProducts.take(5).map((e) => e.value).toList();

      final stats = {
        'totalSales': totalSales,
        'revenue': totalRevenue,
        'avgOrder': avgOrderValue,
        'itemsSold': totalItems,
        'topProducts': topProducts,
      };

      final pdfBytes = await PDFService.generateSalesReportPDF(
        sales: filteredSales,
        startDate: _startDate!,
        endDate: _endDate!,
        shopName: shopName,
        stats: stats,
      );

      await PDFService.printOrSharePDF(
        pdfBytes,
        'sales_report_${DateFormat('yyyy_MM_dd').format(_startDate!)}.pdf',
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
        _isGeneratingPDF = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final salesProvider = Provider.of<SalesProvider>(context);
    final productProvider = Provider.of<ProductProvider>(context);

    final filteredSales = _getFilteredSales(salesProvider.sales);
    final currencyFormat = NumberFormat.currency(symbol: '৳', decimalDigits: 2);
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        actions: [
          IconButton(
            icon: _isGeneratingPDF
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Icon(Icons.print),
            onPressed: _isGeneratingPDF ? null : _generatePDF,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: salesProvider.isLoading || productProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Date Range Selector
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Column(
              children: [
                // Quick Period Filters
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _periods.map((period) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(period),
                          selected: _selectedPeriod == period,
                          onSelected: (selected) {
                            if (period == 'Custom') {
                              _selectDateRange();
                            } else {
                              _setPeriod(period);
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),

                // Date Range Display & Calendar Button
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

          // Reports Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Key Metrics
                  _buildMetricsSection(filteredSales, currencyFormat),
                  const SizedBox(height: 24),

                  // Top Products
                  const Text(
                    'Top Selling Products',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildTopProducts(filteredSales, currencyFormat),
                  const SizedBox(height: 24),

                  // Payment Methods
                  const Text(
                    'Payment Methods',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildPaymentMethods(filteredSales, currencyFormat),
                  const SizedBox(height: 24),

                  // Inventory Status
                  const Text(
                    'Low Stock Alert',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildLowStockProducts(productProvider.products, currencyFormat),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsSection(List<Sale> sales, NumberFormat format) {
    final totalSales = sales.length;
    final totalRevenue = sales.fold<double>(0, (sum, sale) => sum + sale.total);
    final avgOrderValue = totalSales > 0 ? totalRevenue / totalSales : 0.0;
    final totalItems = sales.fold<int>(
      0,
          (sum, sale) => sum + sale.items.fold<int>(
        0,
            (itemSum, item) => itemSum + item.quantity,
      ),
    );

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Total Sales',
                '$totalSales',
                Icons.receipt_long,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Revenue',
                format.format(totalRevenue),
                Icons.attach_money,
                Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Avg Order',
                format.format(avgOrderValue),
                Icons.trending_up,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Items Sold',
                '$totalItems',
                Icons.shopping_bag,
                Colors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopProducts(List<Sale> sales, NumberFormat format) {
    final Map<String, Map<String, dynamic>> productSales = {};

    for (var sale in sales) {
      for (var item in sale.items) {
        if (productSales.containsKey(item.productId)) {
          productSales[item.productId]!['quantity'] += item.quantity;
          productSales[item.productId]!['revenue'] += item.subtotal;
        } else {
          productSales[item.productId] = {
            'name': item.productName,
            'quantity': item.quantity,
            'revenue': item.subtotal,
          };
        }
      }
    }

    final sortedProducts = productSales.entries.toList()
      ..sort((a, b) => b.value['quantity'].compareTo(a.value['quantity']));

    final topProducts = sortedProducts.take(5).toList();

    if (topProducts.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              'No sales data for selected period',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: topProducts.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          final product = topProducts[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green,
              child: Text('${index + 1}'),
            ),
            title: Text(
              product.value['name'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${product.value['quantity']} units sold'),
            trailing: Text(
              format.format(product.value['revenue']),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaymentMethods(List<Sale> sales, NumberFormat format) {
    if (sales.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              'No payment data for selected period',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }

    final Map<String, double> paymentMethods = {};

    for (var sale in sales) {
      paymentMethods[sale.paymentMethod] =
          (paymentMethods[sale.paymentMethod] ?? 0) + sale.total;
    }

    final totalRevenue = sales.fold<double>(0, (sum, s) => sum + s.total);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: paymentMethods.entries.map((entry) {
            final percentage = (entry.value / totalRevenue) * 100;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        format.format(entry.value),
                        style: const TextStyle(color: Colors.green),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: percentage / 100,
                    backgroundColor: Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLowStockProducts(List products, NumberFormat format) {
    final lowStockProducts = products.where((p) => p.stock < 10 && p.isActive).toList();

    if (lowStockProducts.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                'All products have sufficient stock',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: lowStockProducts.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          final product = lowStockProducts[index];
          return ListTile(
            leading: Icon(
              Icons.warning,
              color: product.stock < 5 ? Colors.red : Colors.orange,
            ),
            title: Text(
              product.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('Only ${product.stock} units left'),
            trailing: Text(
              format.format(product.price),
              style: const TextStyle(color: Colors.grey),
            ),
          );
        },
      ),
    );
  }
}