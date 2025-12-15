import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/user.dart';
import '../database/database_helper.dart';

class AuthService {
  static const String _keyUserId = 'user_id';
  static const String _keyUsername = 'username';
  static const String _keyEmail = 'email';
  static const String _keyRole = 'role';
  static const String _keyOrganizationId = 'organization_id';

  // Save login session
  Future<void> saveLoginSession(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserId, user.id);
    await prefs.setString(_keyUsername, user.username);
    if (user.email != null) {
      await prefs.setString(_keyEmail, user.email!);
    }
    await prefs.setString(_keyRole, user.role ?? 'cashier');
    if (user.organizationId != null) {
      await prefs.setString(_keyOrganizationId, user.organizationId!);
    }
  }

  // Get current logged in user
  Future<User?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_keyUserId);
    final username = prefs.getString(_keyUsername);

    if (userId == null || username == null) {
      return null;
    }

    return User(
      id: userId,
      username: username,
      email: prefs.getString(_keyEmail),
      role: prefs.getString(_keyRole) ?? 'cashier',
      organizationId: prefs.getString(_keyOrganizationId),
    );
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_keyUserId);
  }

  // Logout
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyRole);
    await prefs.remove(_keyOrganizationId);
  }

  // Register new user with organization
  Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    String? email,
    required String shopName,
    String? shopAddress,
    String? shopPhone,
    String? shopEmail,
  }) async {
    if (username.isEmpty || password.isEmpty || shopName.isEmpty) {
      return {
        'success': false,
        'message': 'Username, password, and shop name are required',
      };
    }

    if (password.length < 4) {
      return {
        'success': false,
        'message': 'Password must be at least 4 characters',
      };
    }

    final uuid = Uuid();
    final userId = uuid.v4();
    final organizationId = uuid.v4();

    try {
      // Create organization first
      final orgResult = await DatabaseHelper.instance.createOrganization(
        id: organizationId,
        name: shopName,
        ownerId: userId,
        address: shopAddress,
        phone: shopPhone,
        email: shopEmail,
      );

      if (!orgResult['success']) {
        return {
          'success': false,
          'message': orgResult['message'],
        };
      }

      // Create user with organization
      final error = await DatabaseHelper.instance.createUser(
        userId,
        username,
        password,
        email: email,
        role: 'owner', // First user is owner
        organizationId: organizationId,
      );

      if (error != null) {
        return {
          'success': false,
          'message': error,
        };
      }

      final user = User(
        id: userId,
        username: username,
        email: email,
        role: 'owner',
        organizationId: organizationId,
      );

      await saveLoginSession(user);

      return {
        'success': true,
        'user': user,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Registration failed: $e',
      };
    }
  }

  // Login with database validation
  Future<Map<String, dynamic>> login(String username, String password) async {
    if (username.isEmpty || password.isEmpty) {
      return {
        'success': false,
        'message': 'Username and password are required',
      };
    }

    final isValid = await DatabaseHelper.instance.validateUser(username, password);

    if (!isValid) {
      return {
        'success': false,
        'message': 'Invalid username or password',
      };
    }

    final userData = await DatabaseHelper.instance.getUserByUsername(username);

    if (userData == null) {
      return {
        'success': false,
        'message': 'User not found',
      };
    }

    final user = User(
      id: userData['id'],
      username: userData['username'],
      email: userData['email'],
      role: userData['role'] ?? 'cashier',
      organizationId: userData['organization_id'],
    );

    await saveLoginSession(user);

    return {
      'success': true,
      'user': user,
    };
  }
}