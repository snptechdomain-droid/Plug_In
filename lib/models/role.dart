/// Enum for available roles in the system
enum UserRole {
  admin,
  moderator,
  eventCoordinator,
  member,
  guest,
}

/// Extension to convert role to string and vice versa
extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.moderator:
        return 'Lead';
      case UserRole.eventCoordinator:
        return 'Event Coordinator';
      case UserRole.member:
        return 'Member';
      case UserRole.guest:
        return 'Guest';
    }
  }

  String get value {
    return toString().split('.').last;
  }

  static UserRole fromString(String value) {
    switch (value.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'moderator':
        return UserRole.moderator;
      case 'event_coordinator':
        return UserRole.eventCoordinator;
      case 'member':
        return UserRole.member;
      case 'guest':
        return UserRole.guest;
      default:
        return UserRole.guest;
    }
  }
}

/// Model for user permissions based on role
class RolePermissions {
  final UserRole role;
  final List<String> permissions;

  RolePermissions({
    required this.role,
    required this.permissions,
  });

  /// Check if role has specific permission
  bool hasPermission(String permission) {
    return permissions.contains(permission);
  }

  /// Get default permissions for each role
  static RolePermissions getDefaultPermissions(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return RolePermissions(
          role: UserRole.admin,
          permissions: [
            'view_attendance',
            'mark_attendance',
            'view_events',
            'create_events',
            'edit_events',
            'delete_events',
            'view_members',
            'manage_members',
            'view_announcements',
            'create_announcements',
            'edit_announcements',
            'delete_announcements',
            'view_collaboration',
            'create_collaboration',
            'edit_collaboration',
            'delete_collaboration',
            'view_settings',
            'manage_settings',
            'manage_roles',
            'view_reports',
          ],
        );
      case UserRole.moderator:
        return RolePermissions(
          role: UserRole.moderator,
          permissions: [
            'view_attendance',
            'mark_attendance',
            'view_events',
            'create_events',
            'edit_events',
            'view_members',
            'view_announcements',
            'create_announcements',
            'view_collaboration',
            'create_collaboration',
            'view_settings',
          ],
        );
      case UserRole.eventCoordinator:
        return RolePermissions(
          role: UserRole.eventCoordinator,
          permissions: [
             'view_events',
             'create_events',
             'edit_events',
             'delete_events',
             'view_announcements',
             'create_announcements', // Key permission
             'view_members',
             'view_collaboration',
             'create_collaboration', 
          ],
        );
      case UserRole.member:
        return RolePermissions(
          role: UserRole.member,
          permissions: [
            'view_attendance',
            'mark_attendance',
            'view_events',
            'view_members',
            'view_announcements',
            'view_collaboration',
            // 'create_collaboration', // Removed per user request
          ],
        );
      case UserRole.guest:
        return RolePermissions(
          role: UserRole.guest,
          permissions: [
            'view_events',
            'view_announcements',
          ],
        );
    }
  }

  factory RolePermissions.fromJson(Map<String, dynamic> json) {
    return RolePermissions(
      role: UserRoleExtension.fromString(json['role'] ?? 'guest'),
      permissions: List<String>.from(json['permissions'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role': role.value,
      'permissions': permissions,
    };
  }
}

/// Model for user login details
class UserLoginDetails {
  final String id; // Added ID field
  final String username;
  final String email;
  final String passwordHash;
  final UserRole role;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastLogin;
  final String? bio;
  final String? avatarUrl;
  
  // New Fields for Domain Features
  final List<String> domains; // Changed from single String to List
  final String? domain; // Keep for legacy/primary support if needed, or derived from domains first element
  final String? department;
  final String? year;
  final String? section;
  final String? registerNumber;

  UserLoginDetails({
    this.id = '', 
    required this.username,
    required this.email,
    required this.passwordHash,
    required this.role,
    this.isActive = true,
    DateTime? createdAt,
    this.lastLogin,
    this.bio,
    this.avatarUrl,
    this.domains = const [],
    this.domain,
    this.department,
    this.year,
    this.section,
    this.registerNumber,
  }) : createdAt = createdAt ?? DateTime.now();

  factory UserLoginDetails.fromJson(Map<String, dynamic> json) {
    return UserLoginDetails(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      passwordHash: json['passwordHash'] ?? '',
      role: UserRoleExtension.fromString(json['role'] ?? 'guest'),
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] == null 
          ? DateTime.now() 
          : (json['createdAt'] is int 
              ? DateTime.fromMillisecondsSinceEpoch(json['createdAt']) 
              : DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()),
      lastLogin: json['lastLogin'] != null
          ? DateTime.parse(json['lastLogin'])
          : null,
      bio: json['bio'],
      avatarUrl: (json['avatarUrl'] as String?)?.replaceAll('/svg', '/png'),
      domain: json['domain'],
      domains: (json['domains'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      department: json['department'],
      year: json['year'],
      section: json['section'],
      registerNumber: json['registerNumber'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'passwordHash': passwordHash,
      'role': role.value,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'lastLogin': lastLogin?.toIso8601String(),
      'bio': bio,
      'avatarUrl': avatarUrl,
      'domain': domain,
      'domains': domains,
      'department': department,
      'year': year,
      'section': section,
      'registerNumber': registerNumber,
    };
  }

  UserLoginDetails copyWith({
    String? id,
    String? username,
    String? email,
    String? passwordHash,
    UserRole? role,
    bool? isActive,
    DateTime? createdAt,
    DateTime? lastLogin,
    String? bio,
    String? avatarUrl,
    String? domain,
    String? department,
    String? year,
    String? section,
    String? registerNumber,
  }) {
    return UserLoginDetails(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      domain: domain ?? this.domain,
      department: department ?? this.department,
      year: year ?? this.year,
      section: section ?? this.section,
      registerNumber: registerNumber ?? this.registerNumber,
    );
  }
}
