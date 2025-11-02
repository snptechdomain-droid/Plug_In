import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/models/user.dart';

class AuthService {
  static const String _usersKey = 'users';
  static const String _currentUserKey = 'currentUser';
  
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
    if (userStr != null) {
      final userData = jsonDecode(userStr);
      _currentUser = User(
        id: userData['id']?.toString() ?? '',
        username: userData['username']?.toString() ?? '',
        email: userData['email']?.toString() ?? '',
        role: userData['role']?.toString() ?? 'member',
      );
    }
    return _currentUser;
  }

  // Create temporary users for development
  Future<void> createTemporaryUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final usersStr = prefs.getString(_usersKey);

    if (usersStr == null || (jsonDecode(usersStr) as List).isEmpty) {
      final users = [
        {
          'id': '1',
          'username': 'admin',
          'email': 'admin@test.com',
          'password': '12345',
          'role': 'admin',
        },
        {
          'id': '2',
          'username': 'member1',
          'email': 'member1@test.com',
          'password': '12345',
          'role': 'member',
        },
        {
          'id': '3',
          'username': 'member2',
          'email': 'member2@test.com',
          'password': 'password1',
          'role': 'member',
        },
      ];
      await prefs.setString(_usersKey, jsonEncode(users));
    }
  }

  // Register new user
  Future<(bool success, String message)> register({
    required String username,
    required String email,
    required String password,
  }) async {
    if (!isValidEmail(email)) {
      return (false, 'Invalid email format');
    }
    if (!isValidPassword(password)) {
      return (false, 'Password must be at least 6 characters with 1 number');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final usersStr = prefs.getString(_usersKey);
      List<Map<String, dynamic>> users = [];
      
      if (usersStr != null) {
        users = List<Map<String, dynamic>>.from(jsonDecode(usersStr));
        if (users.any((u) => u['email'] == email)) {
          return (false, 'Email already registered');
        }
      }

      final user = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'username': username,
        'email': email,
        'password': password, // In a real app, this should be hashed
        'role': users.isEmpty ? 'admin' : 'member', // First user becomes admin
      };

      users.add(user);
      await prefs.setString(_usersKey, jsonEncode(users));
      await prefs.setString(_currentUserKey, jsonEncode(user));
      
      _currentUser = User(
        id: user['id']?.toString() ?? '',
        username: user['username']?.toString() ?? '',
        email: user['email']?.toString() ?? '',
        role: user['role']?.toString() ?? 'member',
      );

      return (true, 'Registration successful');
    } catch (e) {
      return (false, 'Registration failed: $e');
    }
  }

  // Login user
  Future<(bool success, String message)> login({
    required String email,
    required String password,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersStr = prefs.getString(_usersKey);
      
      if (usersStr == null) {
        return (false, 'No users registered');
      }

      final users = List<Map<String, dynamic>>.from(jsonDecode(usersStr));
      Map<String, dynamic>? user;

      for (final u in users) {
        if (u['email'] == email && u['password'] == password) {
          user = u;
          break;
        }
      }

      if (user == null) {
        return (false, 'Invalid email or password');
      }

      await prefs.setString(_currentUserKey, jsonEncode(user));
      _currentUser = User(
        id: user['id']?.toString() ?? '',
        username: user['username']?.toString() ?? '',
        email: user['email']?.toString() ?? '',
        role: user['role']?.toString() ?? 'member',
      );

      return (true, 'Login successful');
    } catch (e) {
      return (false, 'Login failed: $e');
    }
  }

  // Logout user
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserKey);
    _currentUser = null;
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_currentUserKey);
  }

  // Get user role
  Future<String?> getUserRole() async {
    final user = await loadCurrentUser();
    return user?.role;
  }
}