import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/product_provider.dart';
import '../providers/sales_provider.dart';
import '../providers/auth_provider.dart';
import 'pos_screen.dart';
import 'day_cashbook_screen.dart';
import 'ledger_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      final salesProvider = Provider.of<SalesProvider>(context, listen: false);

      final orgId = authProvider.organizationId;

      productProvider.setOrganizationId(orgId);
      salesProvider.setOrganizationId(orgId);

      productProvider.loadProducts();
      salesProvider.loadSales();
    });
  }

  @override
  Widget build(BuildContext context) {
    final salesProvider = Provider.of<SalesProvider>(context);
    final productProvider = Provider.of<ProductProvider>(context);
    final currencyFormat = NumberFormat.currency(symbol: '৳', decimalDigits: 2);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Stats Cards
          FutureBuilder<Map<String, dynamic>>(
            future: _getQuickStats(salesProvider, productProvider),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final stats = snapshot.data!;
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Today Sales',
                          '${stats['todayCount']}',
                          Icons.shopping_cart,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Revenue',
                          currencyFormat.format(stats['todayRevenue']),
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
                        child: _buildStatCard(
                          'Products',
                          '${stats['totalProducts']}',
                          Icons.inventory,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Low Stock',
                          '${stats['lowStock']}',
                          Icons.warning,
                          Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // Quick Actions
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildActionCard(
                context,
                icon: Icons.point_of_sale,
                title: 'New Sale',
                color: Colors.green,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const POSScreen(),
                    ),
                  );
                },
              ),
              _buildActionCard(
                context,
                icon: Icons.book,
                title: 'Day Cashbook',
                color: Colors.blue,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DayCashbookScreen(),
                    ),
                  );
                },
              ),
              _buildActionCard(
                context,
                icon: Icons.account_balance_wallet,
                title: 'Ledger',
                color: Colors.purple,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LedgerScreen(),
                    ),
                  );
                },
              ),
              _buildActionCard(
                context,
                icon: Icons.analytics,
                title: 'Quick Report',
                color: Colors.orange,
                onTap: () {
                  // Navigate to reports tab
                  // This will be handled by parent navigation
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>> _getQuickStats(
      SalesProvider salesProvider,
      ProductProvider productProvider,
      ) async {
    final todayTotal = await salesProvider.getTodayTotal();
    final todayCount = await salesProvider.getTodayCount();
    final products = productProvider.products;
    final lowStock = products.where((p) => p.stock < 10 && p.isActive).length;

    return {
      'todayCount': todayCount,
      'todayRevenue': todayTotal,
      'totalProducts': products.length,
      'lowStock': lowStock,
    };
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
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

  Widget _buildActionCard(
      BuildContext context, {
        required IconData icon,
        required String title,
        required Color color,
        required VoidCallback onTap,
      }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}