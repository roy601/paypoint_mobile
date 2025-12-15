import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  User? _currentUser;
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get organizationId => _currentUser?.organizationId;

  // Initialize auth state
  Future<void> initAuth() async {
    _currentUser = await _authService.getCurrentUser();
  }

  // Login
  Future<Map<String, dynamic>> login(String username, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _authService.login(username, password);

      if (result['success']) {
        _currentUser = result['user'];
      }

      _isLoading = false;
      notifyListeners();

      return result;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {
        'success': false,
        'message': 'An error occurred',
      };
    }
  }

  // Register with shop
  Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    String? email,
    required String shopName,
    String? shopAddress,
    String? shopPhone,
    String? shopEmail,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _authService.register(
        username: username,
        password: password,
        email: email,
        shopName: shopName,
        shopAddress: shopAddress,
        shopPhone: shopPhone,
        shopEmail: shopEmail,
      );

      if (result['success']) {
        _currentUser = result['user'];
      }

      _isLoading = false;
      notifyListeners();

      return result;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {
        'success': false,
        'message': 'An error occurred',
      };
    }
  }

  // Logout
  Future<void> logout() async {
    await _authService.logout();
    _currentUser = null;
    notifyListeners();
  }
}