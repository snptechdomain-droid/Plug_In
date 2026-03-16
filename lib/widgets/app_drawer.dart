import 'package:flutter/material.dart';
import 'package:app/services/auth_service.dart';
import 'package:app/services/role_database_service.dart';
import 'package:app/models/role.dart';
import 'dart:convert';

class AppDrawer extends StatefulWidget {
  final String currentRoute;

  const AppDrawer({super.key, required this.currentRoute});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String _currentUsername = 'User';
  String? _currentUserAvatar;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final roleDatabase = RoleBasedDatabaseService();
    final user = await roleDatabase.getCurrentUser();
    if (user != null) {
      if (mounted) {
        setState(() {
          _currentUsername = user.username;
          _currentUserAvatar = user.avatarUrl;
          _isAdmin = user.role == UserRole.admin;
        });
      }
    }
  }

  Widget _buildDrawerHeader(BuildContext context) {
    final theme = Theme.of(context);
    return DrawerHeader(
      decoration: BoxDecoration(
        color: theme.appBarTheme.backgroundColor,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: theme.colorScheme.primary,
            backgroundImage: (_currentUserAvatar != null && _currentUserAvatar!.isNotEmpty)
                ? (_currentUserAvatar!.startsWith('http')
                    ? NetworkImage(_currentUserAvatar!)
                    : MemoryImage(base64Decode(_currentUserAvatar!.contains(',') ? _currentUserAvatar!.split(',').last : _currentUserAvatar!)) as ImageProvider)
                : null,
            child: (_currentUserAvatar == null || _currentUserAvatar!.isEmpty)
                ? Text(
                    _currentUsername.isNotEmpty ? _currentUsername.substring(0, 1).toUpperCase() : 'U',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            _currentUsername,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
      BuildContext context, String title, IconData icon, String route,
      {bool isReplacement = false}) {
    final theme = Theme.of(context);
    final isSelected = widget.currentRoute == route;
    final primaryColor = theme.colorScheme.primary;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? primaryColor : theme.iconTheme.color,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? primaryColor : theme.textTheme.bodyLarge?.color,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: primaryColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: () {
        Navigator.pop(context); // Close drawer
        if (isSelected) return; // Already there

        if (isReplacement) {
          Navigator.pushReplacementNamed(context, route);
        } else {
          // If we are navigating to dashboard, use replacement to clear stack
          if (route == '/dashboard') {
            Navigator.pushNamedAndRemoveUntil(context, route, (r) => false);
          } else {
            Navigator.pushNamed(context, route);
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
           SizedBox(
             width: double.infinity,
             child: _buildDrawerHeader(context),
           ),
           Expanded(
             child: ListView(
               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
               children: [
                 _buildDrawerItem(context, 'Home', Icons.home, '/dashboard'),
                 _buildDrawerItem(context, 'Attendance', Icons.co_present, '/attendance'), // Assuming route
                 _buildDrawerItem(context, 'Events', Icons.event, '/events'), // Assuming route exists? Check Main.dart
                 _buildDrawerItem(context, 'Collaboration', Icons.handshake, '/collaboration'),
                 _buildDrawerItem(context, 'Announcements', Icons.campaign, '/announcements'), // Need to register these routes
                 _buildDrawerItem(context, 'Members', Icons.people, '/members'),
                 _buildDrawerItem(context, 'Calendar', Icons.calendar_month, '/calendar'),
                 if (_isAdmin)
                   _buildDrawerItem(context, 'Join Requests', Icons.person_add, '/join_requests'),
                 const Divider(),
                 _buildDrawerItem(context, 'Settings', Icons.settings, '/settings'),
                 ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text('Logout', style: TextStyle(color: Colors.red)),
                    onTap: () async {
                       await RoleBasedDatabaseService().clearCurrentUser();
                       await AuthService().logout();
                       Navigator.of(context).pushNamedAndRemoveUntil('/guest', (route) => false);
                    },
                 ),
               ],
             ),
           ),
        ],
      ),
    );
  }
}
