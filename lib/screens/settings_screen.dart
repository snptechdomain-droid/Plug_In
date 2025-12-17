import 'package:flutter/material.dart';
import 'package:app/services/theme_service.dart';
import 'package:app/services/role_database_service.dart';
import 'package:app/models/role.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:app/screens/user_attendance_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _roleDatabase = RoleBasedDatabaseService();
  UserLoginDetails? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
        _currentLanguage = prefs.getString('language') ?? 'English';
      });
    }
  }

  Future<void> _loadCurrentUser() async {
    final user = await _roleDatabase.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
      });
    }
  }
  bool _notificationsEnabled = true;
  String _currentLanguage = 'English';
  bool _vibrationEnabled = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface.withOpacity(0.97),
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: ListView(
        children: [
          _SettingsHeader('Appearance'),

          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeService,
            builder: (context, mode, _) {
              return _SettingsSwitchTile(
                icon: Icons.dark_mode_rounded,
                color: Colors.purple,
                title: 'Dark Mode',
                value: mode == ThemeMode.dark,
                onChanged: (_) => themeService.toggleTheme(),
              );
            },
          ),

          const Divider(height: 32, indent: 16, endIndent: 16),

          _SettingsHeader('Preferences'),
          _SettingsSwitchTile(
            icon: Icons.notifications_rounded,
            color: Colors.orange,
            title: 'Enable Notifications',
            value: _notificationsEnabled,
            onChanged: (val) async {
              setState(() => _notificationsEnabled = val);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('notifications_enabled', val);
            },
          ),
          _SettingsSwitchTile(
            icon: Icons.vibration_rounded,
            color: Colors.blue,
            title: 'Vibration',
            value: _vibrationEnabled,
            onChanged: (val) =>
                setState(() => _vibrationEnabled = val),
          ),
          _SettingsTile(
            icon: Icons.language_rounded,
            color: Colors.green,
            title: 'Language',
            subtitle: _currentLanguage,
            onTap: _showLanguageDialog,
          ),

          const Divider(height: 32, indent: 16, endIndent: 16),

          _SettingsHeader('Account'),
          _SettingsTile(
            icon: Icons.person,
            color: Colors.teal,
            title: 'Edit Profile',
            subtitle: 'Update your name and bio',
            onTap: () => _showEditProfileDialog(context),
            customImage: (_currentUser?.avatarUrl != null && _currentUser!.avatarUrl!.isNotEmpty)
                ? MemoryImage(base64Decode(_currentUser!.avatarUrl!.split(',').last))
                : null,
          ),

          _SettingsTile(
            icon: Icons.history,
            color: Colors.blueAccent,
            title: 'My Attendance',
            subtitle: 'View your attendance history',
            onTap: () {
               if (_currentUser != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => UserAttendanceScreen(username: _currentUser!.email)),
                );
               }
            },
          ),
          _SettingsTile(
            icon: Icons.notifications,
            color: Colors.orange, // Choose an appropriate color
            title: 'Notifications',
            subtitle: 'Manage app notifications',
            onTap: () {
              // TODO: Implement notification settings
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notification settings coming soon...')),
              );
            },
          ),
          // Add Member (Admin/Moderator only)
          FutureBuilder<UserLoginDetails?>(
            future: RoleBasedDatabaseService().getCurrentUser(),
            builder: (context, snapshot) {
              final user = snapshot.data;
              if (user != null && (user.role == UserRole.admin || user.role == UserRole.moderator)) {
                 return _SettingsTile(
                  icon: Icons.person_add_alt_1_rounded,
                  color: Colors.deepPurple,
                  title: 'Add New Member',
                  subtitle: 'Create a new user account',
                  onTap: () {
                    Navigator.of(context).pushNamed('/register');
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
          _SettingsTile(
            icon: Icons.lock_outline,
            color: Colors.indigo,
            title: 'Privacy Policy',
            subtitle: 'Read our terms and conditions',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Privacy Policy coming soon...')),
              );
            },
          ),

          const Divider(height: 32, indent: 16, endIndent: 16),

          _SettingsHeader('About & Support'),
          _SettingsTile(
            icon: Icons.info_outline,
            color: Colors.blueGrey,
            title: 'About App',
            subtitle: 'App version 1.0.1',
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Slug N Plug',
                applicationVersion: '1.0.1',
                applicationLegalese: '© 2025 Slug N Plug Club',
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.red),
            title: const Text('Logout',
                style: TextStyle(
                    color: Colors.red, fontWeight: FontWeight.w600)),
            onTap: _showLogoutDialog,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // 🌍 Language selection
  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Language'),
        children: ['English', 'Tamil']
            .map(
              (lang) => SimpleDialogOption(
                onPressed: () async {
                  setState(() => _currentLanguage = lang);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('language', lang);
                  Navigator.pop(context);
                },
                child: Text(
                  lang,
                  style: TextStyle(
                    fontWeight: _currentLanguage == lang
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  // ✏️ Edit Profile Dialog
  void _showEditProfileDialog(BuildContext context) {
    final nameController = TextEditingController(text: _currentUser?.username ?? '');
    final bioController = TextEditingController(); 
    // Initialize avatar controller with current avatar URL if available
    // For now, we assume if it starts with 'data:image', it's base64, else it's a URL or empty
    // But since we don't have avatar in UserLoginDetails yet (wait, we need to check if we added it to the model)
    // We haven't added avatarUrl to UserLoginDetails model yet! 
    // I should probably add it to the model first, but for now let's just handle the upload logic.
    // The user asked to "directly upload", so we'll use a local variable to store the base64 string.
    
    String? _newAvatarBase64;
    
    // Password controllers
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    bool showPasswordSection = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Profile'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Avatar Preview & Picker
                  GestureDetector(
                    onTap: () async {
                      final ImagePicker picker = ImagePicker();
                      final XFile? image = await picker.pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 800,
                        maxHeight: 800,
                        imageQuality: 85,
                      );
                      
                      if (image != null) {
                        final bytes = await image.readAsBytes();
                        final base64String = 'data:image/png;base64,${base64Encode(bytes)}';
                        setState(() {
                          _newAvatarBase64 = base64String;
                        });
                      }
                    },
                    child: CircleAvatar(
                      radius: 40,
                      backgroundImage: _newAvatarBase64 != null 
                          ? MemoryImage(base64Decode(_newAvatarBase64!.split(',').last))
                          : (_currentUser?.avatarUrl != null && _currentUser!.avatarUrl!.isNotEmpty)
                              ? MemoryImage(base64Decode(_currentUser!.avatarUrl!.split(',').last))
                              : null,
                      child: (_newAvatarBase64 == null && (_currentUser?.avatarUrl == null || _currentUser!.avatarUrl!.isEmpty))
                          ? const Icon(Icons.add_a_photo, size: 40) 
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Tap to change photo', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Display Name',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: bioController,
                    decoration: const InputDecoration(
                      labelText: 'Bio',
                      prefixIcon: Icon(Icons.info_outline),
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  
                  const Divider(height: 32),
                  
                  // Change Password Section
                  ListTile(
                    title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.bold)),
                    trailing: Icon(showPasswordSection ? Icons.expand_less : Icons.expand_more),
                    onTap: () => setState(() => showPasswordSection = !showPasswordSection),
                  ),
                  
                  if (showPasswordSection) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: newPassController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'New Password',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: confirmPassController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm New Password',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        if (newPassController.text.isEmpty) {
                           ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Password cannot be empty')),
                          );
                          return;
                        }
                        if (newPassController.text != confirmPassController.text) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Passwords do not match')),
                          );
                          return;
                        }
                        
                        final success = await _roleDatabase.changePassword(
                          _currentUser!.email,
                          newPassController.text,
                        );
                        
                        if (context.mounted) {
                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Password changed successfully')),
                            );
                            // Clear fields
                            newPassController.clear();
                            confirmPassController.clear();
                            setState(() => showPasswordSection = false);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Failed to change password')),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red,
                      ),
                      child: const Text('Update Password'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_currentUser == null) return;
                
                  final currentAvatar = _currentUser?.avatarUrl;
                  final avatarToSend = _newAvatarBase64 ?? currentAvatar ?? '';
                  
                  final success = await _roleDatabase.updateUserProfile(
                    _currentUser!.email, 
                    nameController.text,
                    bioController.text,
                    avatarToSend,
                  );
                if (success) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Profile updated successfully')),
                    );
                    _loadCurrentUser(); 
                  }
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to update profile')),
                    );
                  }
                }
              },
              child: const Text('Save Profile'),
            ),
          ],
        ),
      ),
    );
  }

  // 🚪 Logout confirmation
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await RoleBasedDatabaseService().clearCurrentUser();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                    context, '/guest', (_) => false);
              }
            },
            child:
                const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// -------------------- UI COMPONENTS --------------------

class _SettingsHeader extends StatelessWidget {
  final String title;
  const _SettingsHeader(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding:
            const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 8.0),
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
      );
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final ImageProvider? customImage;
  const _SettingsTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.customImage,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin:
          const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        leading: customImage != null 
            ? CircleAvatar(
                backgroundColor: color.withOpacity(0.1),
                backgroundImage: customImage,
              )
            : CircleAvatar(
                backgroundColor: color.withOpacity(0.1),
                foregroundColor: color,
                child: Icon(icon),
              ),
        title: Text(title,
            style:
                const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        trailing:
            const Icon(Icons.chevron_right, color: Colors.grey),
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SettingsSwitchTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin:
          const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        secondary: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          foregroundColor: color,
          child: Icon(icon),
        ),
        title: Text(title,
            style:
                const TextStyle(fontWeight: FontWeight.w500)),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
