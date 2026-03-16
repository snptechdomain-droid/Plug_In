import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/models/user.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class AuthService {
  static const String _usersKey = 'users_database'; // Align with RoleBasedDatabaseService
  static const String _currentUserKey = 'current_user'; // Align with RoleBasedDatabaseService
  
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  User? _currentUser;
  User? get currentUser => _currentUser;

  // Email validation
  bool isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+').hasMatch(email);
  }

  // Password validation (min 6 chars, at least 1 number)
  bool isValidPassword(String password) {
    return password.length >= 6 && RegExp(r'[0-9]').hasMatch(password);
  }

  // Load current user on app start
  Future<User?> loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString(_currentUserKey);

    if (userStr == null || userStr.isEmpty) {
      _currentUser = null;
      return null;
    }

    try {
      final userData = jsonDecode(userStr);
      _currentUser = User(
        id: userData['id']?.toString() ?? '',
        username: userData['username']?.toString() ?? '',
        email: userData['email']?.toString() ?? '',
        role: userData['role']?.toString() ?? 'member',
      );
    } catch (_) {
      _currentUser = null;
    }

    return _currentUser;
  }

  // Create temporary users for development (Deprecated/Unused but kept for syntax fix)
  Future<void> createTemporaryUsers() async {
    // No-op or fix syntax
    final prefs = await SharedPreferences.getInstance();
    // ... logic removed to avoid confusion, or just keep empty
  }

  // Register new user (Deprecated - use RoleBasedDatabaseService)
  Future<(bool success, String message)> register({
    required String username,
    required String email,
    required String password,
  }) async {
      return (false, 'Use RoleBasedDatabaseService');
  }

  // Login user (Deprecated - use RoleBasedDatabaseService)
  Future<(bool success, String message)> login({
    required String email,
    required String password,
  }) async {
      return (false, 'Use RoleBasedDatabaseService');
  }

  // Logout user
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserKey);

    // Ensure we clear in-memory state too (important for hot reload)
    _currentUser = null;

    if (kDebugMode) {
      final stillHas = prefs.containsKey(_currentUserKey);
      if (stillHas) {
        debugPrint('AuthService.logout: key $_currentUserKey still present after remove');
      }
    }
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();

    if (!prefs.containsKey(_currentUserKey)) {
      return false;
    }

    // Validate stored user data; clear if invalid.
    final userStr = prefs.getString(_currentUserKey);
    if (userStr == null || userStr.isEmpty) {
      await prefs.remove(_currentUserKey);
      _currentUser = null;
      return false;
    }

    try {
      final userData = jsonDecode(userStr);
      if (userData is Map<String, dynamic>) {
        final username = userData['username']?.toString();
        if (username == null || username.isEmpty) {
          await prefs.remove(_currentUserKey);
          _currentUser = null;
          return false;
        }
      }
    } catch (_) {
      await prefs.remove(_currentUserKey);
      _currentUser = null;
      return false;
    }

    return true;
  }

  // Get user role
  Future<String?> getUserRole() async {
    final user = await loadCurrentUser();
    return user?.role;
  }
}