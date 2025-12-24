import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:app/models/domain.dart';
import 'package:app/models/role.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class RoleBasedDatabaseService {
  static final RoleBasedDatabaseService _instance =
  RoleBasedDatabaseService._internal();

  static DateTime parseDate(dynamic dateValue) {
    if (dateValue == null) return DateTime.now();
    try {

      return DateTime.parse(dateValue.toString());
    } catch (e) {
      print('Error parsing date: $e');
      return DateTime.now();
    }
  }

  factory RoleBasedDatabaseService() {
    return _instance;
  }

  RoleBasedDatabaseService._internal();

  SharedPreferences? _prefs;
  static const String _usersKey = 'users_database';
  static const String _currentUserKey = 'current_user';
  bool _isInitialized = false;

  /// Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;
    _prefs = await SharedPreferences.getInstance();
    _isInitialized = true;
    await _initializeDefaultUsers();
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized || _prefs == null) {
      await initialize();
    }
  }

  /// Initialize default admin and test users
  Future<void> _initializeDefaultUsers() async {
    final usersJson = _prefs?.getString(_usersKey);

    if (usersJson == null) {
      // Create default users if database is empty
      final defaultUsers = [
        UserLoginDetails(
          username: 'admin',
          email: 'admin@snpclub.com',
          passwordHash: _hashPassword('admin123'),
          role: UserRole.admin,
          isActive: true,
        ),
        UserLoginDetails(
          username: 'moderator',
          email: 'moderator@snpclub.com',
          passwordHash: _hashPassword('moderator123'),
          role: UserRole.moderator,
          isActive: true,
        ),
        UserLoginDetails(
          username: 'member1',
          email: 'member1@snpclub.com',
          passwordHash: _hashPassword('member123'),
          role: UserRole.member,
          isActive: true,
        ),
        UserLoginDetails(
          username: 'guest',
          email: 'guest@snpclub.com',
          passwordHash: _hashPassword('guest123'),
          role: UserRole.guest,
          isActive: true,
        ),
      ];

      for (var user in defaultUsers) {
        await addUser(user);
      }
    }
  }

  /// Hash password using SHA-256
  static String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  /// Add a new user
  Future<bool> addUser(UserLoginDetails user) async {
    try {
      final users = await getAllUsers();

      // Check if user already exists
      if (users.any((u) => u.username == user.username)) {
        return false;
      }

      users.add(user);
      await _saveUsers(users);
      return true;
    } catch (e) {
      print('Error adding user: $e');
      return false;
    }
  }

  /// Update user details
  Future<bool> updateUser(UserLoginDetails user) async {
    try {
      final users = await getAllUsers();
      final index = users.indexWhere((u) => u.username == user.username);

      if (index == -1) {
        return false;
      }

      users[index] = user;
      await _saveUsers(users);
      return true;
    } catch (e) {
      print('Error updating user: $e');
      return false;
    }
  }

  /// Delete a user
  Future<bool> deleteUser(String username) async {
    try {
      final users = await getAllUsers();
      final initialLength = users.length;
      users.removeWhere((u) => u.username == username);

      if (users.length == initialLength) {
        return false;
      }

      await _saveUsers(users);
      return true;
    } catch (e) {
      print('Error deleting user: $e');
      return false;
    }
  }

  /// Get user by username
  Future<UserLoginDetails?> getUserByUsername(String username) async {
    try {
      final users = await getAllUsers();
      return users.firstWhere(
            (u) => u.username == username,
        orElse: () => UserLoginDetails(
          username: '',
          email: '',
          passwordHash: '',
          role: UserRole.guest,
        ),
      ).username.isEmpty
          ? null
          : users.firstWhere((u) => u.username == username);
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }



  /// Authenticate user with username and password via Backend API
  Future<(UserLoginDetails?, String?)> authenticateUser(
      String username, String password) async {
    final url = Uri.parse('${_getBaseUrl()}/api/auth/login');
    try {
      print('Attempting login to: $url');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final user = UserLoginDetails(
          username: data['displayName'] ?? data['email'],
          email: data['email'],
          passwordHash: data['passwordHash'] ?? '',
          role: UserRoleExtension.fromString(data['role'] ?? 'GUEST'),
          isActive: true,
          createdAt: data['createdAt'] != null ? DateTime.parse(data['createdAt']) : DateTime.now(),
          lastLogin: DateTime.now(),
          bio: data['bio'],
          avatarUrl: data['avatarUrl'],
        );

        await setCurrentUser(user);
        return (user, null); // Success
      } else if (response.statusCode == 404) {
        return (null, "Username or Email not found.");
      } else if (response.statusCode == 401) {
        return (null, "Incorrect password.");
      } else if (response.statusCode == 429) {
        return (null, "Too many attempts. Try later.");
      } else {
        return (null, "Server Error: ${response.statusCode}");
      }
    } catch (e) {
      print('Error authenticating user at $url: $e');
      return (null, "Connection failed. Check internet.");
    }
  }

  /// Register new user via Backend API
  Future<(bool success, String message)> register({
    required String username,
    required String password,
    required String key,
    String? registerNumber,
    String? year,
    String? section,
    String? department,
    Domain? domain,
  }) async {
    try {
      final url = Uri.parse('${_getBaseUrl()}/api/auth/register');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'key': key,
          if (registerNumber != null) 'registerNumber': registerNumber,
          if (year != null) 'year': year,
          if (section != null) 'section': section,
          if (department != null) 'department': department,
          if (domain != null) 'domain': domain.apiValue,
        }),
      );

      if (response.statusCode == 200) {
        return (true, 'Registration successful');
      } else {
        return (false, response.body);
      }
    } catch (e) {
      return (false, 'Registration failed: $e');
    }
  }

  /// Get all users (Backend + Local fallback)
  Future<List<UserLoginDetails>> getAllUsers() async {
    // 1. Try fetching from Backend
    try {
      final viewer = await getCurrentUser();
      final viewerEmail = viewer?.email;
      final url = Uri.parse(
          '${_getBaseUrl()}/api/users${viewerEmail != null ? '?viewerEmail=${Uri.encodeComponent(viewerEmail)}' : ''}');
      final response = await http.get(url).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final backendUsers = data.map((json) {
          return UserLoginDetails(
            username: json['displayName'] ?? json['username'] ?? json['email'] ?? 'Unknown',
            email: json['email'] ?? '',
            passwordHash: '',
            role: UserRoleExtension.fromString(json['role'] ?? 'GUEST'),
            isActive: true,
            bio: json['bio'],
            avatarUrl: json['avatarUrl'],
            domain: DomainExtension.fromString(json['domain']),
            registerNumber: json['registerNumber'],
            year: json['year'],
            section: json['section'],
            department: json['department'],
          );
        }).toList();
        return backendUsers;
      }
    } catch (e) {
      print('Error fetching users from backend: $e. Falling back to local.');
    }

    // 2. Fallback to Local Storage
    try {
      await _ensureInitialized();
      final usersJson = _prefs?.getString(_usersKey);
      if (usersJson == null) {
        return [];
      }
      final List<dynamic> decoded = jsonDecode(usersJson);
      return decoded
          .map((u) => UserLoginDetails.fromJson(u as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting all users locally: $e');
      return [];
    }
  }

  /// Get users by role
  Future<List<UserLoginDetails>> getUsersByRole(UserRole role) async {
    try {
      final users = await getAllUsers();
      return users.where((u) => u.role == role).toList();
    } catch (e) {
      print('Error getting users by role: $e');
      return [];
    }
  }

  /// Save users to SharedPreferences
  Future<void> _saveUsers(List<UserLoginDetails> users) async {
    try {
      await _ensureInitialized();
      final jsonList = users.map((u) => u.toJson()).toList();
      final encoded = jsonEncode(jsonList);
      await _prefs?.setString(_usersKey, encoded);
    } catch (e) {
      print('Error saving users: $e');
    }
  }

  /// Set current logged-in user
  Future<void> setCurrentUser(UserLoginDetails user) async {
    try {
      await _ensureInitialized();
      await _prefs?.setString(_currentUserKey, jsonEncode(user.toJson()));
    } catch (e) {
      print('Error setting current user: $e');
    }
  }

  /// Get current logged-in user
  Future<UserLoginDetails?> getCurrentUser() async {
    try {
      await _ensureInitialized();
      final userJson = _prefs?.getString(_currentUserKey);

      if (userJson == null) {
        return null;
      }

      return UserLoginDetails.fromJson(jsonDecode(userJson));
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }

  /// Clear current user (logout)
  Future<void> clearCurrentUser() async {
    try {
      await _ensureInitialized();
      await _prefs?.remove(_currentUserKey);
    } catch (e) {
      print('Error clearing current user: $e');
    }
  }

  /// Get permissions for current user
  Future<RolePermissions?> getCurrentUserPermissions() async {
    try {
      final user = await getCurrentUser();

      if (user == null) {
        return null;
      }

      return RolePermissions.getDefaultPermissions(user.role);
    } catch (e) {
      print('Error getting current user permissions: $e');
      return null;
    }
  }

  /// Check if current user has permission
  Future<bool> hasPermission(String permission) async {
    try {
      final permissions = await getCurrentUserPermissions();

      if (permissions == null) {
        return false;
      }

      return permissions.hasPermission(permission);
    } catch (e) {
      print('Error checking permission: $e');
      return false;
    }
  }





  /// Deactivate/activate user
  Future<bool> setUserActive(String username, bool isActive) async {
    try {
      final user = await getUserByUsername(username);

      if (user == null) {
        return false;
      }

      final updatedUser = user.copyWith(isActive: isActive);
      return await updateUser(updatedUser);
    } catch (e) {
      print('Error setting user active status: $e');
      return false;
    }
  }
  // --- Backend Integration Methods ---

  Future<List<Map<String, dynamic>>> fetchUserAttendance(String username) async {
    try {
      final response = await http.get(
        Uri.parse('${_getBaseUrl()}/api/attendance/user/$username'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('Error fetching user attendance: $e');
      return [];
    }
  }

  String _getBaseUrl() {
    // Allows the Android Emulator to connect to your local IntelliJ backend
    if (kDebugMode) {
      return 'http://10.0.2.2:7860';
    }
    // Production Cloud URL
    return 'https://snp-tech-backend.hf.space';
  }
  /// Fetch all users from Backend API
  Future<List<UserLoginDetails>> fetchAllUsers() async {
    try {
      final viewer = await getCurrentUser();
      final viewerEmail = viewer?.email;
      final url = Uri.parse(
          '${_getBaseUrl()}/api/users${viewerEmail != null ? '?viewerEmail=${Uri.encodeComponent(viewerEmail)}' : ''}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => UserLoginDetails(
          username: json['displayName'] ?? json['username'] ?? '',
          email: json['email'] ?? '',
          passwordHash: '',
          role: UserRoleExtension.fromString(json['role'] ?? 'MEMBER'),
          isActive: json['active'] ?? true,
          createdAt: DateTime.now(),
          lastLogin: DateTime.now(),
          bio: json['bio'],
          avatarUrl: json['avatarUrl'],
          domain: DomainExtension.fromString(json['domain']),
          registerNumber: json['registerNumber'],
          year: json['year'],
          section: json['section'],
          department: json['department'],
        ))
            .toList();
      } else {
        print('Failed to fetch users: ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error fetching users: $e');
      return [];
    }
  }

  /// Update user profile via Backend API
  Future<bool> updateUserProfile(String username, String displayName, String bio, String? avatarUrl) async {
    try {
      final url = Uri.parse('${_getBaseUrl()}/api/users/$username');
      final body = {
        'displayName': displayName,
        'bio': bio,
      };
      if (avatarUrl != null && avatarUrl.isNotEmpty) {
        body['avatarUrl'] = avatarUrl;
      }

      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        // Sync local cache
        final currentUser = await getCurrentUser();
        if (currentUser != null && currentUser.email == username) {
          final updatedUser = currentUser.copyWith(
            username: displayName,
            bio: bio,
            avatarUrl: avatarUrl,
          );
          await setCurrentUser(updatedUser);
        }
        return true;
      } else {
        print('Failed to update profile: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error updating profile: $e');
      return false;
    }
  }

  /// Change user password via Backend API
  Future<(bool, String)> changePassword(String username, String newPassword) async {
    try {
      final encodedUsername = Uri.encodeComponent(username);
      final url = Uri.parse('${_getBaseUrl()}/api/users/$encodedUsername/password');
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'newPassword': newPassword,
        }),
      );

      if (response.statusCode == 200) {
        return (true, 'Password updated successfully');
      } else {
        return (false, 'Failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error changing password: $e');
      return (false, 'Connection error: $e');
    }
  }

  // ---- Forgot Password Flow ----
  Future<(bool, String?)> requestPasswordReset(String usernameOrEmail) async {
    try {
      final url = Uri.parse('${_getBaseUrl()}/api/users/forgot-password/request');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'usernameOrEmail': usernameOrEmail}),
      );
      if (response.statusCode == 200) {
        return (true, null);
      }
      if (response.statusCode == 404) {
        return (false, 'User does not exist');
      }
      return (false, response.body.isNotEmpty ? response.body : 'Unable to start reset');
    } catch (e) {
      print('Error requesting password reset: $e');
      return (false, 'Connection error');
    }
  }

  Future<(bool, String?)> verifyPasswordOtp(String usernameOrEmail, String otp) async {
    try {
      final url = Uri.parse('${_getBaseUrl()}/api/users/forgot-password/verify');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'usernameOrEmail': usernameOrEmail, 'otp': otp}),
      );
      if (response.statusCode == 200) return (true, null);
      if (response.statusCode == 404) return (false, 'User does not exist');
      return (false, 'Invalid OTP');
    } catch (e) {
      print('Error verifying OTP: $e');
      return (false, 'Connection error');
    }
  }

  Future<(bool, String?)> resetPasswordWithOtp(
      String usernameOrEmail, String otp, String newPassword) async {
    try {
      final url = Uri.parse('${_getBaseUrl()}/api/users/forgot-password/reset');
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'usernameOrEmail': usernameOrEmail,
          'otp': otp,
          'newPassword': newPassword,
        }),
      );

      if (response.statusCode == 200) {
        return (true, null);
      }
      return (false, response.body.isNotEmpty ? response.body : null);
    } catch (e) {
      print('Error resetting password: $e');
      return (false, e.toString());
    }
  }

  Future<bool> changeUserRole(String username, String newRole, {Domain? domain}) async {
    try {
      final url = Uri.parse('${_getBaseUrl()}/api/users/$username/role');
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'role': newRole,
          if (domain != null) 'domain': domain.apiValue,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error changing user role: $e');
      return false;
    }
  }

  /// Fetch only active members for coordinator dropdown
  Future<List<UserLoginDetails>> fetchMembers() async {
    try {
      final viewer = await getCurrentUser();
      final viewerEmail = viewer?.email;
      final url = Uri.parse(
          '${_getBaseUrl()}/api/users/members${viewerEmail != null ? '?viewerEmail=${Uri.encodeComponent(viewerEmail)}' : ''}');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data
            .map((json) => UserLoginDetails(
          username: json['displayName'] ?? json['email'] ?? '',
          email: json['email'] ?? '',
          passwordHash: '',
          role: UserRoleExtension.fromString(json['role'] ?? 'MEMBER'),
          isActive: json['active'] ?? true,
          avatarUrl: json['avatarUrl'],
          domain: DomainExtension.fromString(json['domain']),
          registerNumber: json['registerNumber'],
          year: json['year'],
          section: json['section'],
          department: json['department'],
        ))
            .toList();
      }
    } catch (e) {
      print('Error fetching members: $e');
    }
    return [];
  }

  Future<bool> deleteUserFromBackend(String username) async {
    try {
      final url = Uri.parse('${_getBaseUrl()}/api/users/$username');
      final response = await http.delete(url);
      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting user: $e');
      return false;
    }
  }

  Future<UserLoginDetails?> fetchUserProfile(String query) async {
    try {
      final viewer = await getCurrentUser();
      final viewerEmail = viewer?.email;
      final encodedQuery = Uri.encodeComponent(query);
      final url = Uri.parse(
          '${_getBaseUrl()}/api/users/find?query=$encodedQuery${viewerEmail != null ? '&viewerEmail=${Uri.encodeComponent(viewerEmail)}' : ''}');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UserLoginDetails.fromJson(data);
      } else {
        print('Failed to fetch profile: ${response.body}');
      }
    } catch (e) {
      print('Error fetching profile: $e');
    }
    return null;
  }

  // -------------------- ANNOUNCEMENT METHODS --------------------

  Future<List<dynamic>> fetchAnnouncements() async {
    try {
      final url = Uri.parse('${_getBaseUrl()}/api/announcements');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Error fetching announcements: $e');
    }
    return [];
  }

  Future<bool> createAnnouncement(String title, String content, String authorName) async {
    try {
      final url = Uri.parse('${_getBaseUrl()}/api/announcements');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': title,
          'content': content,
          'authorName': authorName,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error creating announcement: $e');
      return false;
    }
  }

  Future<int> getUnreadAnnouncementCount(String userId) async {
    try {
      final url = Uri.parse('${_getBaseUrl()}/api/announcements/unread-count/$userId');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return int.tryParse(response.body) ?? 0;
      }
    } catch (e) {
      print('Error fetching unread count: $e');
    }
    return 0;
  }

  Future<void> markAnnouncementsRead(String userId) async {
    try {
      final url = Uri.parse('${_getBaseUrl()}/api/announcements/mark-read/$userId');
      await http.post(url);
    } catch (e) {
      print('Error marking announcements read: $e');
    }
  }

  // -------------------- ATTENDANCE METHODS --------------------

  Future<bool> registerForEvent(String eventId, Map<String, String> registrationData) async {
    try {
      final url = Uri.parse('${_getBaseUrl()}/api/events/$eventId/register');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(registrationData),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error registering for event: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchAttendanceRecords() async {
    try {
      final url = Uri.parse('${_getBaseUrl()}/api/attendance');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      print('Error fetching attendance: $e');
    }
    return [];
  }

  Future<bool> markAttendance(List<String> presentUserIds, String notes) async {
    try {
      final url = Uri.parse('${_getBaseUrl()}/api/attendance');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'presentUserIds': presentUserIds,
          'notes': notes,
          'date': DateTime.now().toUtc().toIso8601String(),
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error marking attendance: $e');
      return false;
    }
  }

  Future<String?> updateAttendance(String id, List<String> presentUserIds, String notes) async {
    try {
      final url = Uri.parse('${_getBaseUrl()}/api/attendance/$id');
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'presentUserIds': presentUserIds,
          'notes': notes,
        }),
      );

      if (response.statusCode == 200) {
        return null; // Success
      } else if (response.statusCode == 403) {
        return 'Time limit passed (1 hour).';
      } else if (response.statusCode == 404 || response.statusCode == 405) {
        return 'Server endpoint not found. Please restart backend.';
      } else {
        return 'Failed with status: ${response.statusCode}';
      }
    } catch (e) {
      print('Error updating attendance: $e');
      return 'Connection error: $e';
    }
  }

  Future<bool> deleteAttendance(String id) async {
    try {
      final url = Uri.parse('${_getBaseUrl()}/api/attendance/$id');
      final response = await http.delete(url);
      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting attendance: $e');
      return false;
    }
  }

  // -------------------- PROJECT & POLL METHODS --------------------

  Future<String?> _getToken() async {
    return "dummy_token";
  }

  Future<List<Map<String, dynamic>>> getUserProjects(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('${_getBaseUrl()}/api/projects?userId=$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      print('Error fetching projects: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> createProject(String title, String ownerId) async {
    try {
      final response = await http.post(
        Uri.parse('${_getBaseUrl()}/api/projects'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': title,
          'ownerId': ownerId,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Error creating project: $e');
    }
    return null;
  }

  Future<bool> deleteProject(String projectId) async {
    try {
      final response = await http.delete(
        Uri.parse('${_getBaseUrl()}/api/projects/$projectId'),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting project: $e');
      return false;
    }
  }

  Future<bool> addMemberToProject(String projectId, String username, {String role = 'EDITOR'}) async {
    try {
      final response = await http.post(
        Uri.parse('${_getBaseUrl()}/api/projects/$projectId/members'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'role': role,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error adding member: $e');
      return false;
    }
  }

  Future<bool> createPoll(String projectId, String question, List<String> options, {bool multiSelect = false}) async {
    try {
      final response = await http.post(
        Uri.parse('${_getBaseUrl()}/api/projects/$projectId/polls'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'question': question,
          'options': options,
          'createdBy': (await getCurrentUser())?.email,
          'multiSelect': multiSelect,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error creating poll: $e');
      return false;
    }
  }

  Future<bool> votePoll(String projectId, String pollId, String userId, int optionIndex) async {
    try {
      final response = await http.post(
        Uri.parse('${_getBaseUrl()}/api/projects/$projectId/polls/$pollId/vote'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'optionIndex': optionIndex,
        }),
      );

      print('Vote Poll Response: ${response.statusCode} - ${response.body}');
      if (response.statusCode != 200) {
        print('Failed to vote: ${response.body}');
      }
      return response.statusCode == 200;
    } catch (e) {
      print('Error voting poll: $e');
      return false;
    }
  }

  Future<bool> deletePoll(String projectId, String pollId) async {
    try {
      final response = await http.delete(
        Uri.parse('${_getBaseUrl()}/api/projects/$projectId/polls/$pollId'),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting poll: $e');
      return false;
    }
  }



  Future<bool> togglePollStatus(String projectId, String pollId) async {
    try {
      final response = await http.put(
        Uri.parse('${_getBaseUrl()}/api/projects/$projectId/polls/$pollId/status'),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error toggling poll status: $e');
      return false;
    }
  }

  Future<bool> updateProjectData(String projectId, {String? flowchartData, String? mindmapData, String? timelineData}) async {
    final body = <String, String>{};
    if (flowchartData != null) body['flowchartData'] = flowchartData;
    if (mindmapData != null) body['mindmapData'] = mindmapData;
    if (timelineData != null) body['timelineData'] = timelineData;

    if (body.isEmpty) return true;

    try {
      final response = await http.post(
        Uri.parse('${_getBaseUrl()}/api/projects/$projectId/data'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating project data: $e');
      return false;
    }
  }
  // -------------------- EVENT METHODS --------------------

  Future<List<dynamic>> fetchEvents({bool publicOnly = false}) async {
    try {
      final endpoint = publicOnly ? '/api/events/public' : '/api/events';
      final url = Uri.parse('${_getBaseUrl()}$endpoint');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        // Decode directly as list of maps; the model parsing happens in UI or specific model class
        // But here we return dynamic list to be flexible
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Error fetching events: $e');
    }
    return [];
  }

  Future<bool> createEvent(Map<String, dynamic> eventData) async {
    try {
      final url = Uri.parse('${_getBaseUrl()}/api/events');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(eventData),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error creating event: $e');
      return false;
    }
  }

  Future<bool> deleteEvent(String eventId) async {
    try {
      final url = Uri.parse('${_getBaseUrl()}/api/events/$eventId');
      final response = await http.delete(url);
      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting event: $e');
      return false;
    }
  }

  Future<bool> updateEvent(String eventId, Map<String, dynamic> eventData) async {
    try {
      final url = Uri.parse('${_getBaseUrl()}/api/events/$eventId');
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(eventData),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating event: $e');
      return false;
    }
  }

  // -------------------- MEMBERSHIP REQUEST METHODS --------------------

  Future<bool> submitMembershipRequest(Map<String, dynamic> requestData) async {
    try {
      final url = Uri.parse('${_getBaseUrl()}/api/membership/request');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestData),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error submitting membership request: $e');
      return false;
    }
  }

  Future<List<dynamic>> fetchMembershipRequests() async {
    try {
      final url = Uri.parse('${_getBaseUrl()}/api/membership');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Error fetching membership requests: $e');
    }
    return [];
  }

  Future<bool> updateMembershipRequestStatus(String requestId, String status) async {
    try {
      final url = Uri.parse('${_getBaseUrl()}/api/membership/$requestId/status');
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: status, // Sending raw string body as controller expects @RequestBody String
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating membership request: $e');
      return false;
    }
  }
}
