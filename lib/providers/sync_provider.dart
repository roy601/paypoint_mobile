import 'package:flutter/foundation.dart';
import '../services/sync_service.dart';
import '../services/connectivity_service.dart';

class SyncProvider with ChangeNotifier {
  final SyncService _syncService = SyncService();
  final ConnectivityService _connectivityService = ConnectivityService();

  bool _isSyncing = false;
  bool _isOnline = false;
  String? _lastSyncMessage;
  DateTime? _lastSyncTime;
  String? _organizationId;

  bool get isSyncing => _isSyncing;
  bool get isOnline => _isOnline;
  String? get lastSyncMessage => _lastSyncMessage;
  DateTime? get lastSyncTime => _lastSyncTime;

  SyncProvider() {
    _initConnectivity();
    _listenToConnectivity();
  }

  void setOrganizationId(String? orgId) {
    _organizationId = orgId;
  }

  // Initialize connectivity status
  Future<void> _initConnectivity() async {
    _isOnline = await _connectivityService.isOnline();
    notifyListeners();
  }

  // Listen to connectivity changes
  void _listenToConnectivity() {
    _connectivityService.onConnectivityChanged.listen((online) {
      _isOnline = online;
      notifyListeners();

      if (online) {
        // Auto-sync when connection is restored
        autoSync();
      }
    });
  }

  // Manual sync
  Future<void> manualSync() async {
    if (_isSyncing) return;

    _isSyncing = true;
    _lastSyncMessage = null;
    notifyListeners();

    try {
      final result = await _syncService.syncAll(
        organizationId: _organizationId,
      );

      _lastSyncMessage = result['message'];
      if (result['success']) {
        _lastSyncTime = DateTime.now();
      }
    } catch (e) {
      _lastSyncMessage = 'Sync failed: $e';
    }

    _isSyncing = false;
    notifyListeners();
  }

  // Auto sync (called on app start or when connectivity restored)
  Future<void> autoSync() async {
    if (_isSyncing || !_isOnline) return;

    _isSyncing = true;
    notifyListeners();

    try {
      await _syncService.syncAll(organizationId: _organizationId);
      _lastSyncTime = DateTime.now();
      _lastSyncMessage = 'Auto-sync completed';
    } catch (e) {
      _lastSyncMessage = 'Auto-sync failed: $e';
    }

    _isSyncing = false;
    notifyListeners();
  }

  // Sync specific data types
  Future<void> syncProducts() async {
    if (_isSyncing || !_isOnline) return;

    _isSyncing = true;
    notifyListeners();

    try {
      await _syncService.syncProducts(organizationId: _organizationId);
      _lastSyncTime = DateTime.now();
      _lastSyncMessage = 'Products synced';
    } catch (e) {
      _lastSyncMessage = 'Products sync failed: $e';
    }

    _isSyncing = false;
    notifyListeners();
  }

  Future<void> syncSales() async {
    if (_isSyncing || !_isOnline) return;

    _isSyncing = true;
    notifyListeners();

    try {
      await _syncService.syncSales(organizationId: _organizationId);
      _lastSyncTime = DateTime.now();
      _lastSyncMessage = 'Sales synced';
    } catch (e) {
      _lastSyncMessage = 'Sales sync failed: $e';
    }

    _isSyncing = false;
    notifyListeners();
  }
}