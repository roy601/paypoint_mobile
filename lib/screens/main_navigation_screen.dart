import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/sync_provider.dart';
import 'home_screen.dart';
import 'products_screen.dart';
import 'sales_history_screen.dart';
import 'reports_screen.dart';
import 'pos_screen.dart';
import 'settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';


class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  bool _showQuickSaleFAB = false;

  final List<Widget> _screens = [
    const HomeScreen(),
    const ProductsScreen(),
    const SalesHistoryScreen(),
    const ReportsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadQuickSalePreference();
  }

  Future<void> _loadQuickSalePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showQuickSaleFAB = prefs.getBool('show_quick_sale_fab') ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final syncProvider = Provider.of<SyncProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_getTitle()),
            if (user != null && _currentIndex == 0)
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

          // Settings button
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
              // Reload preference after returning from settings
              _loadQuickSalePreference();
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: 'Products',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Sales',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Reports',
          ),
        ],
      ),
      floatingActionButton: _showQuickSaleFAB
          ? FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const POSScreen(),
            ),
          );
        },
        backgroundColor: Colors.green,
        child: const Icon(Icons.add_shopping_cart),
      )
          : null,
    );
  }

  String _getTitle() {
    switch (_currentIndex) {
      case 0:
        return 'PayPoint POS';
      case 1:
        return 'Products';
      case 2:
        return 'Sales History';
      case 3:
        return 'Reports';
      default:
        return 'PayPoint POS';
    }
  }
}