import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/product_provider.dart';
import '../providers/sync_provider.dart';
import '../providers/sales_provider.dart';
import 'products_screen.dart';

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
      final syncProvider = Provider.of<SyncProvider>(context, listen: false);

      final orgId = authProvider.organizationId;

      // Set organization ID for all providers
      productProvider.setOrganizationId(orgId);
      salesProvider.setOrganizationId(orgId);
      syncProvider.setOrganizationId(orgId);

      // Load data
      productProvider.loadProducts();
      syncProvider.autoSync();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final syncProvider = Provider.of<SyncProvider>(context);
    final user = authProvider.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('PayPoint POS'),
            if (user != null)
              Text(
                'Welcome, ${user.username}',
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        actions: [
          // Sync status indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                Icon(
                  syncProvider.isOnline ? Icons.cloud_done : Icons.cloud_off,
                  color: syncProvider.isOnline ? Colors.green : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  syncProvider.isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontSize: 12,
                    color: syncProvider.isOnline ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
          ),

          // Manual sync button
          IconButton(
            icon: syncProvider.isSyncing
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Icon(Icons.sync),
            onPressed: syncProvider.isSyncing
                ? null
                : () async {
              await syncProvider.manualSync();
              if (mounted && syncProvider.lastSyncMessage != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(syncProvider.lastSyncMessage!),
                    backgroundColor: syncProvider.lastSyncMessage!
                        .contains('success')
                        ? Colors.green
                        : Colors.orange,
                  ),
                );
              }
            },
          ),

          // Logout button
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );

              if (confirm == true && mounted) {
                await authProvider.logout();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Sync status banner
          if (syncProvider.lastSyncTime != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.blue.shade50,
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Last synced: ${DateFormat('MMM dd, yyyy hh:mm a').format(syncProvider.lastSyncTime!)}',
                      style: const TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),

          // Menu grid
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(16),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _buildMenuCard(
                  context,
                  icon: Icons.inventory,
                  title: 'Products',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProductsScreen(),
                      ),
                    );
                  },
                ),
                _buildMenuCard(
                  context,
                  icon: Icons.inventory,
                  title: 'Products',
                  color: Colors.blue,
                  onTap: () {
                    // TODO: Navigate to Products screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Products Screen - Coming next!')),
                    );
                  },
                ),
                _buildMenuCard(
                  context,
                  icon: Icons.history,
                  title: 'Sales History',
                  color: Colors.orange,
                  onTap: () {
                    // TODO: Navigate to Sales History
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Sales History - Coming next!')),
                    );
                  },
                ),
                _buildMenuCard(
                  context,
                  icon: Icons.analytics,
                  title: 'Reports',
                  color: Colors.purple,
                  onTap: () {
                    // TODO: Navigate to Reports
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Reports - Coming next!')),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(
      BuildContext context, {
        required IconData icon,
        required String title,
        required Color color,
        required VoidCallback onTap,
      }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: color,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}